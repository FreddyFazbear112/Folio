import SwiftUI
import SceneKit
import PDFKit
import UIKit

/// A small interactive book stage. PDFKit renders the user's real PDF pages
/// into SceneKit page materials; no placeholder text is used in the book.
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
    @State private var sepia = true
    @State private var coverImage: UIImage?
    @State private var loadError: String?
    @State private var turning = false

    private var total: Int { document?.pageCount ?? 0 }

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.13, blue: 0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold))
                            .frame(width: 42, height: 42).background(.white.opacity(0.09), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("FOLIO").font(.system(size: 9, weight: .bold)).tracking(2.5)
                        Text(title).font(.system(size: 14, design: .serif)).lineLimit(1)
                    }
                    Spacer()
                    Button { sepia.toggle(); refreshScene() } label: {
                        Image(systemName: sepia ? "moon" : "sun.max").font(.system(size: 14))
                            .frame(width: 42, height: 42).background(.white.opacity(0.09), in: Circle())
                    }
                }
                .foregroundStyle(Color(red: 0.94, green: 0.89, blue: 0.78))
                .padding(.horizontal, 20).padding(.top, 12)

                Spacer(minLength: 12)
                if let document, total > 0 {
                    SceneBookStage(
                        leftPage: page > 1 ? renderedPage(page - 1, in: document) : nil,
                        rightPage: renderedPage(page, in: document),
                        cover: coverImage ?? coverArtwork,
                        isOpen: isOpen,
                        pageNumber: page,
                        paper: sepia ? UIColor(red: 0.94, green: 0.90, blue: 0.81, alpha: 1) : UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1),
                        onTapCover: { withAnimation(.easeInOut(duration: 0.8)) { isOpen.toggle() } }
                    )
                    .frame(height: 390)
                    .padding(.horizontal, 8)
                    .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                        guard isOpen else { withAnimation(.easeInOut(duration: 0.8)) { isOpen = true }; return }
                        if value.translation.width < -35 { turn(1) }
                        if value.translation.width > 35 { turn(-1) }
                    })
                } else if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.ellipsis").font(.system(size: 30, weight: .ultraLight))
                        Text("This reading copy couldn't be opened").font(.system(size: 18, design: .serif))
                        Text(loadError).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white).frame(height: 390).padding(.horizontal, 30)
                } else {
                    ProgressView("Preparing your book…").tint(.white).foregroundStyle(.white)
                        .frame(height: 390)
                }
                Spacer(minLength: 12)
                VStack(spacing: 15) {
                    HStack(spacing: 34) {
                        Button { turn(-1) } label: { Image(systemName: "chevron.left") }
                            .disabled(!isOpen || page <= 1)
                        Text(total > 0 ? "PAGE \(page) OF \(total)" : "OPENING")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.4)
                        Button { turn(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(!isOpen || page >= total)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.94, green: 0.78, blue: 0.53))
                    if total > 0 {
                        ProgressView(value: Double(page), total: Double(total))
                            .tint(Color(red: 0.78, green: 0.62, blue: 0.39))
                    }
                    Text(isOpen ? "SWIPE TO TURN THE PAGE" : "TAP THE COVER TO OPEN YOUR BOOK")
                        .font(.system(size: 8, weight: .medium)).tracking(1.6)
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.horizontal, 28).padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard let loaded = PDFDocument(url: url), loaded.pageCount > 0 else {
                loadError = "The PDF may be damaged, encrypted, or unavailable. Try importing it again."
                return
            }
            document = loaded
            page = min(max(initialPage, 1), loaded.pageCount)
            withAnimation(.easeInOut(duration: 0.85)) { isOpen = true }
            onProgress(page, loaded.pageCount)
            if let coverURL, let remoteURL = URL(string: coverURL), remoteURL.scheme == "https",
               let (data, _) = try? await URLSession.shared.data(from: remoteURL),
               let image = UIImage(data: data) {
                coverImage = image
            }
        }
        .onChange(of: page) { _, value in if total > 0 { onProgress(value, total) } }
    }

    private func turn(_ delta: Int) {
        guard isOpen, total > 0 else { return }
        let next = min(max(page + delta, 1), total)
        guard next != page else { return }
        guard !turning else { return }
        turning = true
        page = next
        SoundEffects.pageTurn()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { turning = false }
    }

    private func renderedPage(_ number: Int, in document: PDFDocument) -> UIImage? {
        guard let pdfPage = document.page(at: min(max(number - 1, 0), document.pageCount - 1)) else { return nil }
        return pdfPage.thumbnail(of: CGSize(width: 900, height: 1260), for: .mediaBox)
    }

    private var coverArtwork: UIImage {
        let size = CGSize(width: 900, height: 1260)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0.18, green: 0.27, blue: 0.28, alpha: 1),
                UIColor(red: 0.09, green: 0.14, blue: 0.16, alpha: 1)
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\\.cgColor) as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia", size: 76) ?? UIFont.systemFont(ofSize: 76),
                .foregroundColor: UIColor(red: 0.91, green: 0.78, blue: 0.57, alpha: 1),
                .paragraphStyle: paragraph
            ]
            title.draw(in: CGRect(x: 70, y: 430, width: 760, height: 300), withAttributes: attributes)
            let imprint: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                .kern: 7
            ]
            "FOLIO EDITION".draw(at: CGPoint(x: 310, y: 1120), withAttributes: imprint)
        }
    }

    private func refreshScene() { }
}

private struct SceneBookStage: UIViewRepresentable {
    let leftPage: UIImage?
    let rightPage: UIImage?
    let cover: UIImage?
    let isOpen: Bool
    let pageNumber: Int
    let paper: UIColor
    var onTapCover: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = makeScene()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        view.addGestureRecognizer(tap)
        context.coordinator.onTap = onTapCover
        context.coordinator.coverPivot = view.scene?.rootNode.childNode(withName: "cover-hinge", recursively: true)
        context.coordinator.lastPageNumber = pageNumber
        context.coordinator.lastLeftPage = leftPage
        context.coordinator.lastRightPage = rightPage
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onTap = onTapCover
        guard let scene = view.scene else { return }
        if let previousPage = context.coordinator.lastPageNumber,
           previousPage != pageNumber {
            let movingForward = pageNumber > previousPage
            let turningImage = movingForward ? context.coordinator.lastRightPage : context.coordinator.lastLeftPage
            let reverseImage = movingForward ? context.coordinator.lastLeftPage : context.coordinator.lastRightPage
            animatePageTurn(in: scene, movingForward: movingForward, front: turningImage, reverse: reverseImage)
        }
        scene.rootNode.childNode(withName: "left-page", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = leftPage ?? paper
        scene.rootNode.childNode(withName: "right-page", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = rightPage ?? paper
        scene.rootNode.childNode(withName: "paper-block", recursively: true)?.geometry?.materials.forEach { $0.diffuse.contents = paper }
        if let cover { scene.rootNode.childNode(withName: "front-cover", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = cover }
        context.coordinator.lastPageNumber = pageNumber
        context.coordinator.lastLeftPage = leftPage
        context.coordinator.lastRightPage = rightPage
        if let hinge = context.coordinator.coverPivot {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.65
            hinge.eulerAngles.y = isOpen ? -.pi : 0
            SCNTransaction.commit()
        }
    }

    /// Adds a temporary paper leaf at the spine and rotates it across the book.
    /// The static page surfaces underneath are already updated with the next PDF
    /// pages, so the real document remains the source of every visible page.
    private func animatePageTurn(in scene: SCNScene, movingForward: Bool, front: UIImage?, reverse: UIImage?) {
        guard let front else { return }
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = front
        frontMaterial.lightingModel = .lambert
        frontMaterial.roughness.contents = 0.92

        // The pivot stays on the spine; the page itself is offset to the
        // fore-edge, which makes the sheet sweep across the book rather
        // than spin around its own centre.
        let hinge = SCNNode()
        hinge.position = SCNVector3(0, 0, 0.075)
        let leaf = SCNNode(geometry: SCNPlane(width: 2.85, height: 4.17))
        leaf.geometry?.materials = [frontMaterial]
        leaf.position.x = movingForward ? 1.425 : -1.425
        leaf.castsShadow = true
        leaf.renderingOrder = 10
        hinge.addChildNode(leaf)

        if let reverse {
            let backMaterial = SCNMaterial()
            backMaterial.diffuse.contents = reverse
            backMaterial.lightingModel = .lambert
            backMaterial.roughness.contents = 0.92
            let back = SCNNode(geometry: SCNPlane(width: 2.85, height: 4.17))
            back.geometry?.materials = [backMaterial]
            back.position.z = -0.002
            back.eulerAngles.y = .pi
            leaf.addChildNode(back)
        }
        scene.rootNode.addChildNode(hinge)

        let flip = SCNAction.rotateTo(
            x: 0,
            y: movingForward ? -.pi : .pi,
            z: 0,
            duration: 0.58,
            usesShortestUnitArc: false
        )
        flip.timingMode = .easeInEaseOut
        hinge.runAction(flip) { [weak hinge] in
            DispatchQueue.main.async { hinge?.removeFromParentNode() }
        }
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode
        let paperBlock = SCNBox(width: 5.82, height: 4.25, length: 0.20, chamferRadius: 0.045)
        let blockMaterial = SCNMaterial()
        blockMaterial.diffuse.contents = paper
        paperBlock.materials = Array(repeating: blockMaterial, count: 6)
        let block = SCNNode(geometry: paperBlock)
        block.name = "paper-block"
        block.position.z = -0.10
        root.addChildNode(block)

        func pageNode(_ name: String, x: Float) -> SCNNode {
            let plane = SCNPlane(width: 1.47, height: 4.17)
            let material = SCNMaterial()
            material.diffuse.contents = paper
            material.isDoubleSided = true
            material.lightingModel = .lambert
            plane.materials = [material]
            let node = SCNNode(geometry: plane)
            node.name = name
            node.position = SCNVector3(x, 0, 0.0)
            root.addChildNode(node)
            return node
        }
        pageNode("left-page", x: -1.45)
        pageNode("right-page", x: 1.45)

        let hinge = SCNNode()
        hinge.name = "cover-hinge"
        hinge.position = SCNVector3(0, 0, 0.09)
        let coverPlane = SCNPlane(width: 2.96, height: 4.34)
        let coverMaterial = SCNMaterial()
        coverMaterial.diffuse.contents = cover ?? paper
        coverMaterial.isDoubleSided = true
        coverMaterial.roughness.contents = 0.86
        coverPlane.materials = [coverMaterial]
        let coverNode = SCNNode(geometry: coverPlane)
        coverNode.name = "front-cover"
        coverNode.position.x = 1.48
        hinge.addChildNode(coverNode)
        root.addChildNode(hinge)

        let light = SCNNode()
        let lamp = SCNLight()
        lamp.type = .omni
        lamp.intensity = 900
        lamp.color = UIColor(red: 1, green: 0.88, blue: 0.69, alpha: 1)
        light.light = lamp
        light.position = SCNVector3(-1.8, 3.5, 5)
        root.addChildNode(light)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 13.0)
        root.addChildNode(cameraNode)
        return scene
    }

    final class Coordinator: NSObject {
        var onTap: (() -> Void)?
        weak var coverPivot: SCNNode?
        var lastPageNumber: Int?
        var lastLeftPage: UIImage?
        var lastRightPage: UIImage?
        @objc func tapped() { onTap?() }
    }
}
