import SwiftUI
import SceneKit
import PDFKit
import UIKit

enum ReaderPaperTheme: String, CaseIterable, Identifiable {
    case sepia = "Sepia"
    case dark = "Dark"
    case light = "Light"
    var id: String { rawValue }

    var paperColor: UIColor {
        switch self {
        case .sepia: return UIColor(red: 0.93, green: 0.87, blue: 0.76, alpha: 1.0)
        case .dark:  return UIColor(red: 0.14, green: 0.13, blue: 0.12, alpha: 1.0)
        case .light: return UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)
        }
    }

    var swatchColor: Color {
        switch self {
        case .sepia: return Color(red: 0.86, green: 0.77, blue: 0.62)
        case .dark:  return Color(red: 0.16, green: 0.14, blue: 0.13)
        case .light: return Color(red: 0.96, green: 0.95, blue: 0.92)
        }
    }
}

struct Folio3DBookReader: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let title: String
    let coverURL: String?
    let initialPage: Int
    var onProgress: (Int, Int) -> Void

    @State private var document: PDFDocument?
    @State private var page = 1
    @State private var isOpen = false
    @State private var coverImage: UIImage?
    @State private var loadError: String?
    @State private var flipTrigger = 0
    @State private var flipDirection = 1

    @State private var showSettings = false
    @State private var paperTheme: ReaderPaperTheme = .sepia
    @State private var textZoom: Double = 1.0
    @State private var autoNightMode = true
    @State private var pageTurnAnimation = true

    private var total: Int { document?.pageCount ?? 0 }
    private let goldAccent = Color(red: 0.85, green: 0.71, blue: 0.49)

    var body: some View {
        ZStack {
            // Warm dark desk atmosphere matching mockup
            RadialGradient(
                colors: [
                    Color(red: 0.17, green: 0.13, blue: 0.10),
                    Color(red: 0.06, green: 0.05, blue: 0.04)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 8)

                if let document, total > 0 {
                    PhysicalBook3DStage(
                        leftPageImage: page > 1 ? renderedPage(page - 1, in: document) : nil,
                        rightPageImage: renderedPage(page, in: document),
                        nextPageImage: page < total ? renderedPage(page + 1, in: document) : nil,
                        coverImage: coverImage ?? generatedHardcover,
                        isOpen: isOpen,
                        paperColor: paperTheme.paperColor,
                        flipTrigger: flipTrigger,
                        flipDirection: flipDirection,
                        animateTurns: pageTurnAnimation,
                        onTapCover: {
                            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                                isOpen.toggle()
                            }
                        },
                        onTurnRequest: { delta in
                            turn(delta)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                guard isOpen else {
                                    withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                                        isOpen = true
                                    }
                                    return
                                }
                                if value.translation.width < -30 { turn(1) }
                                if value.translation.width > 30 { turn(-1) }
                            }
                    )
                } else if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(goldAccent)
                        Text("Unable to open book")
                            .font(.system(size: 19, design: .serif))
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(28)
                } else {
                    ProgressView("Opening edition…")
                        .tint(goldAccent)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            readerSettingsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            guard let loaded = PDFDocument(url: url), loaded.pageCount > 0 else {
                loadError = "The PDF file could not be read. Try importing it again."
                return
            }
            document = loaded
            page = min(max(initialPage, 1), loaded.pageCount)
            onProgress(page, loaded.pageCount)

            if let coverURL,
               let remoteURL = URL(string: coverURL),
               remoteURL.scheme == "https",
               let (data, _) = try? await URLSession.shared.data(from: remoteURL),
               let img = UIImage(data: data) {
                coverImage = img
            }

            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                isOpen = true
            }
        }
        .onChange(of: page) { _, newValue in
            if total > 0 {
                onProgress(newValue, total)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text(isOpen ? "3D READING VIEW" : "TAP COVER TO OPEN")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(goldAccent.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 8) {
                Button { showSettings = true } label: {
                    Text("Aa")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.08), in: Circle())
                }

                Button {
                    withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                        isOpen.toggle()
                    }
                } label: {
                    Image(systemName: isOpen ? "book.closed" : "book")
                        .font(.system(size: 15))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.08), in: Circle())
                }
            }
        }
        .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if total > 0 {
                Text("\(page) / \(total)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 14) {
                    Button { turn(-1) } label: {
                        Image(systemName: "text.justify.left")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .disabled(!isOpen || page <= 1)

                    Slider(
                        value: Binding(
                            get: { Double(page) },
                            set: { page = max(1, min(total, Int($0.rounded()))) }
                        ),
                        in: 1...Double(max(1, total)),
                        step: 1
                    )
                    .tint(goldAccent)
                    .disabled(!isOpen)

                    Button { turn(1) } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .disabled(!isOpen || page >= total)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private var readerSettingsSheet: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Text("Reader Settings")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { showSettings = false }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(goldAccent)
            }
            .padding(.top, 8)

            VStack(spacing: 14) {
                HStack {
Text("Page Zoom")
.font(.subheadline)
Spacer()
HStack(spacing: 12) {
Text("A").font(.caption)
Slider(value: $textZoom, in: 0.85...1.35)
.tint(goldAccent)
.frame(width: 150)
Text("A").font(.title3)
}
}
Divider().overlay(.white.opacity(0.1))
VStack(alignment: .leading, spacing: 10) {
Text("Theme")
.font(.subheadline)
HStack(spacing: 12) {
ForEach(ReaderPaperTheme.allCases) { item in
Button {
paperTheme = item
} label: {
VStack(spacing: 6) {
RoundedRectangle(cornerRadius: 10, style: .continuous)
.fill(item.swatchColor)
.frame(height: 44)
.overlay(
RoundedRectangle(cornerRadius: 10, style: .continuous)
.strokeBorder(
paperTheme == item ? goldAccent : .white.opacity(0.15),
lineWidth: paperTheme == item ? 2 : 1
)
)
Text(item.rawValue)
.font(.caption2.weight(.medium))
.foregroundStyle(paperTheme == item ? goldAccent : .secondary)
}
}
.buttonStyle(.plain)
}
}
}
Divider().overlay(.white.opacity(0.1))
Toggle("Auto Night Mode", isOn: $autoNightMode)
.tint(goldAccent)
Toggle("Page Turn Animation", isOn: $pageTurnAnimation)
.tint(goldAccent)
}
.padding(16)
.background(Color(red: 0.14, green: 0.12, blue: 0.11), in: RoundedRectangle(cornerRadius: 18))
Spacer()
}
.padding(.horizontal, 18)
.background(Color(red: 0.09, green: 0.08, blue: 0.07).ignoresSafeArea())
}
private func turn(_ delta: Int) {
guard isOpen, total > 0 else { return }
let next = min(max(page + delta, 1), total)
guard next != page else { return }
flipDirection = delta
flipTrigger += 1
page = next
SoundEffects.pageTurn()
}
private func renderedPage(_ number: Int, in document: PDFDocument) -> UIImage? {
let idx = min(max(number - 1, 0), document.pageCount - 1)
guard let pdfPage = document.page(at: idx) else { return nil }
let bounds = pdfPage.bounds(for: .mediaBox)
let targetSize = CGSize(width: 960, height: 1360)
return UIGraphicsImageRenderer(size: targetSize).image { ctx in
paperTheme.paperColor.setFill()
ctx.fill(CGRect(origin: .zero, size: targetSize))
ctx.cgContext.saveGState()
ctx.cgContext.translateBy(x: 0, y: targetSize.height)
ctx.cgContext.scaleBy(x: 1, y: -1)
let scaleX = (targetSize.width * 0.90) / max(1, bounds.width)
let scaleY = (targetSize.height * 0.90) / max(1, bounds.height)
let scale = min(scaleX, scaleY) * textZoom
let offsetX = (targetSize.width - bounds.width * scale) / 2
let offsetY = (targetSize.height - bounds.height * scale) / 2
ctx.cgContext.translateBy(x: offsetX, y: offsetY)
ctx.cgContext.scaleBy(x: scale, y: scale)
if paperTheme == .dark {
ctx.cgContext.setBlendMode(.difference)
}
pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
ctx.cgContext.restoreGState()
}
}
private var generatedHardcover: UIImage {
let size = CGSize(width: 900, height: 1300)
return UIGraphicsImageRenderer(size: size).image { ctx in
let colors = [
UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1),
UIColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1)
]
let grad = CGGradient(
colorsSpace: CGColorSpaceCreateDeviceRGB(),
colors: colors.map(.cgColor) as CFArray,
locations: [0, 1]
)!
ctx.cgContext.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
UIColor(red: 0.85, green: 0.71, blue: 0.49, alpha: 0.55).setStroke()
let frame = UIBezierPath(roundedRect: CGRect(x: 48, y: 48, width: size.width - 96, height: size.height - 96), cornerRadius: 16)
frame.lineWidth = 4
frame.stroke()
let style = NSMutableParagraphStyle()
style.alignment = .center
title.draw(
in: CGRect(x: 80, y: 460, width: size.width - 160, height: 340),
withAttributes: [
.font: UIFont(name: "Georgia-Bold", size: 68) ?? UIFont.boldSystemFont(ofSize: 68),
.foregroundColor: UIColor(red: 0.90, green: 0.77, blue: 0.55, alpha: 1),
.paragraphStyle: style
]
)
}
}
}
private struct PhysicalBook3DStage: UIViewRepresentable {
let leftPageImage: UIImage?
let rightPageImage: UIImage?
let nextPageImage: UIImage?
let coverImage: UIImage
let isOpen: Bool
let paperColor: UIColor
let flipTrigger: Int
let flipDirection: Int
let animateTurns: Bool
var onTapCover: () -> Void
var onTurnRequest: (Int) -> Void
func makeCoordinator() -> Coordinator { Coordinator() }
func makeUIView(context: Context) -> SCNView {
let view = SCNView()
view.backgroundColor = .clear
view.antialiasingMode = .multisampling4X
view.isPlaying = true
let scene = buildBookScene()
view.scene = scene
let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
view.addGestureRecognizer(tap)
context.coordinator.sceneView = view
context.coordinator.coverHinge = scene.rootNode.childNode(withName: "front-cover-hinge", recursively: true)
context.coordinator.turningLeaf = scene.rootNode.childNode(withName: "turning-leaf-hinge", recursively: true)
context.coordinator.bookAssembly = scene.rootNode.childNode(withName: "book-assembly", recursively: true)
return view
}
func updateUIView(_ view: SCNView, context: Context) {
context.coordinator.onTapCover = onTapCover
context.coordinator.onTurnRequest = onTurnRequest
context.coordinator.isOpen = isOpen
guard let scene = view.scene else { return }
scene.rootNode.childNode(withName: "left-curved-page", recursively: true)?
.geometry?.firstMaterial?.diffuse.contents = leftPageImage ?? paperColor
scene.rootNode.childNode(withName: "right-curved-page", recursively: true)?
.geometry?.firstMaterial?.diffuse.contents = rightPageImage ?? paperColor
scene.rootNode.childNode(withName: "front-cover-board", recursively: true)?
.geometry?.firstMaterial?.diffuse.contents = coverImage
if let assembly = context.coordinator.bookAssembly {
SCNTransaction.begin()
SCNTransaction.animationDuration = 0.75
assembly.position.x = isOpen ? 0.0 : -0.78
assembly.eulerAngles.x = isOpen ? -0.26 : -0.18
SCNTransaction.commit()
}
if let hinge = context.coordinator.coverHinge {
SCNTransaction.begin()
SCNTransaction.animationDuration = 0.75
hinge.eulerAngles.y = isOpen ? -.pi * 0.96 : 0
SCNTransaction.commit()
}
if context.coordinator.lastFlipTrigger != flipTrigger {
context.coordinator.lastFlipTrigger = flipTrigger
if animateTurns, let leaf = context.coordinator.turningLeaf {
leaf.geometry?.firstMaterial?.diffuse.contents = nextPageImage ?? paperColor
leaf.isHidden = false
leaf.eulerAngles.y = flipDirection > 0 ? 0 : -.pi * 0.94
SCNTransaction.begin()
SCNTransaction.animationDuration = 0.36
SCNTransaction.completionBlock = { leaf.isHidden = true }
leaf.eulerAngles.y = flipDirection > 0 ? -.pi * 0.94 : 0
SCNTransaction.commit()
}
}
}
private func buildBookScene() -> SCNScene {
let scene = SCNScene()
let root = scene.rootNode
let assembly = SCNNode()
assembly.name = "book-assembly"
assembly.eulerAngles = SCNVector3(-0.22, 0, 0)
root.addChildNode(assembly)
// Back hardcover board
let backBoard = SCNBox(width: 3.16, height: 4.38, length: 0.06, chamferRadius: 0.02)
let leatherMat = SCNMaterial()
leatherMat.diffuse.contents = UIColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1)
leatherMat.roughness.contents = 0.75
backBoard.materials = [leatherMat]
let backNode = SCNNode(geometry: backBoard)
backNode.position = SCNVector3(0, 0, -0.16)
assembly.addChildNode(backNode)
// Stacked paper page thickness block
let pageStack = SCNBox(width: 3.04, height: 4.24, length: 0.22, chamferRadius: 0.02)
let edgeMat = SCNMaterial()
edgeMat.diffuse.contents = UIColor(red: 0.85, green: 0.78, blue: 0.66, alpha: 1)
pageStack.materials = [edgeMat]
let stackNode = SCNNode(geometry: pageStack)
stackNode.position = SCNVector3(0, 0, -0.02)
assembly.addChildNode(stackNode)
// Curved left and right open pages with natural center gutter dip
let leftCurved = SCNNode(geometry: makeCurvedPageGeometry(width: 1.50, height: 4.20, isLeft: true))
leftCurved.name = "left-curved-page"
leftCurved.position = SCNVector3(-0.75, 0, 0.095)
assembly.addChildNode(leftCurved)
let rightCurved = SCNNode(geometry: makeCurvedPageGeometry(width: 1.50, height: 4.20, isLeft: false))
rightCurved.name = "right-curved-page"
rightCurved.position = SCNVector3(0.75, 0, 0.095)
assembly.addChildNode(rightCurved)
// Animated page-turn leaf
let leafPivot = SCNNode()
leafPivot.name = "turning-leaf-hinge"
leafPivot.position = SCNVector3(0, 0, 0.11)
leafPivot.isHidden = true
let leafGeo = makeCurvedPageGeometry(width: 1.50, height: 4.20, isLeft: false)
let leafMesh = SCNNode(geometry: leafGeo)
leafMesh.position = SCNVector3(0.75, 0, 0)
leafPivot.addChildNode(leafMesh)
assembly.addChildNode(leafPivot)
// Front hardcover hinged at the center spine (x = 0)
let coverHinge = SCNNode()
coverHinge.name = "front-cover-hinge"
coverHinge.position = SCNVector3(0, 0, 0.11)
let frontBoard = SCNBox(width: 1.58, height: 4.38, length: 0.05, chamferRadius: 0.02)
let coverMat = SCNMaterial()
coverMat.diffuse.contents = coverImage
coverMat.roughness.contents = 0.65
frontBoard.materials = [coverMat, leatherMat, leatherMat, leatherMat, leatherMat, leatherMat]
let frontNode = SCNNode(geometry: frontBoard)
frontNode.name = "front-cover-board"
frontNode.position = SCNVector3(0.79, 0, 0)
coverHinge.addChildNode(frontNode)
assembly.addChildNode(coverHinge)
// Warm reading lamp lighting
let keyLight = SCNNode()
keyLight.light = SCNLight()
keyLight.light?.type = .omni
keyLight.light?.intensity = 1050
keyLight.light?.color = UIColor(red: 1.0, green: 0.90, blue: 0.74, alpha: 1.0)
keyLight.position = SCNVector3(-1.4, 3.2, 6.2)
root.addChildNode(keyLight)
let fillLight = SCNNode()
fillLight.light = SCNLight()
fillLight.light?.type = .ambient
fillLight.light?.intensity = 320
fillLight.light?.color = UIColor(red: 0.95, green: 0.88, blue: 0.78, alpha: 1.0)
root.addChildNode(fillLight)
let camera = SCNCamera()
camera.fieldOfView = 34
let camNode = SCNNode()
camNode.camera = camera
camNode.position = SCNVector3(0, -0.1, 10.6)
root.addChildNode(camNode)
return scene
}
private func makeCurvedPageGeometry(width: Float, height: Float, isLeft: Bool) -> SCNGeometry {
let cols = 20
let rows = 2
var vertices: [SCNVector3] = []
var uvs: [CGPoint] = []
var indices: [Int32] = []
for r in 0...rows {
let v = Float(r) / Float(rows)
let y = (v - 0.5) * height
for c in 0...cols {
let u = Float(c) / Float(cols)
let x = (u - 0.5) * width
// Distance from center spine (u = 1 for left page, u = 0 for right page)
let distFromSpine = isLeft ? (1.0 - u) : u
let archZ = sin(distFromSpine * .pi) * 0.11 - (1.0 - distFromSpine) * 0.04
vertices.append(SCNVector3(x, y, archZ))
uvs.append(CGPoint(x: CGFloat(u), y: CGFloat(1.0 - v)))
}
}
let stride = cols + 1
for r in 0..<rows {
for c in 0..<cols {
let i0 = Int32(r * stride + c)
let i1 = i0 + 1
let i2 = i0 + Int32(stride)
let i3 = i2 + 1
indices.append(contentsOf: [i0, i2, i1, i1, i2, i3])
}
}
let vSrc = SCNGeometrySource(vertices: vertices)
let uvSrc = SCNGeometrySource(textureCoordinates: uvs)
let el = SCNGeometryElement(indices: indices, primitiveType: .triangles)
let geo = SCNGeometry(sources: [vSrc, uvSrc], elements: [el])
let mat = SCNMaterial()
mat.diffuse.contents = paperColor
mat.isDoubleSided = true
mat.roughness.contents = 0.90
geo.materials = [mat]
return geo
}
final class Coordinator: NSObject {
weak var sceneView: SCNView?
weak var coverHinge: SCNNode?
weak var turningLeaf: SCNNode?
weak var bookAssembly: SCNNode?
var isOpen = false
var lastFlipTrigger = 0
var onTapCover: (() -> Void)?
var onTurnRequest: ((Int) -> Void)?
@objc func handleTap(_ gesture: UITapGestureRecognizer) {
guard let view = sceneView else { return }
let loc = gesture.location(in: view)
if !isOpen {
onTapCover?()
return
}
if loc.x < view.bounds.width * 0.35 {
onTurnRequest?(-1)
} else if loc.x > view.bounds.width * 0.65 {
onTurnRequest?(1)
}
}
}
}