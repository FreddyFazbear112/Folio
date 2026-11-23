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
            ZStack {
                Image("ReadingRoom").resizable().scaledToFill().overlay(LinearGradient(colors: [Color.black.opacity(0.42), Color.black.opacity(0.68), Color.black.opacity(0.94)], startPoint: .top, endPoint: .bottom))
                RadialGradient(colors: [Color(red: 0.48, green: 0.28, blue: 0.14).opacity(0.24), .clear], center: .top, startRadius: 10, endRadius: 520)
            }.ignoresSafeArea()
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

                HStack(alignment: .lastTextBaseline) {
                    Text("NOW READING").font(.system(size: 8, weight: .bold)).tracking(2.2).foregroundStyle(Color(red: 0.86, green: 0.67, blue: 0.44))
                    Spacer()
                    Text(isOpen ? "OPEN EDITION" : "CLOTHBOUND EDITION").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.48))
                }.padding(.horizontal, 25).padding(.top, 20)
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
                    .frame(maxWidth: .infinity).frame(height: 500)
                    .padding(.horizontal, 2)
                    .background(Color.clear)
                    .shadow(color: .black.opacity(0.72), radius: 30, x: 0, y: 24)
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
            // PDFKit can take noticeable time to parse large files. Never do
            // that synchronous work on SwiftUI's main actor or the whole reader
            // appears frozen on its loading state.
            let loaded = await Task.detached(priority: .userInitiated) {
                PDFDocument(url: url)
            }.value
            guard !Task.isCancelled else { return }
            guard let loaded, loaded.pageCount > 0 else {
                loadError = "Folio couldn't read this PDF. It may be damaged, encrypted, or unavailable. Re-import the file and try again."
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
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map { $0.cgColor } as CFArray, locations: [0, 1])!
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
        view.isOpaque = false
        view.contentMode = .scaleAspectFit
        let scene = makeScene()
        view.scene = scene
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = false
        view.isJitteringEnabled = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        if let camera = scene.rootNode.childNode(withName: "folio-camera", recursively: true) {
            camera.look(at: SCNVector3Zero)
            view.pointOfView = camera
        }
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
            // When open, tuck the front board behind the left page leaf.
            // Without this depth change the thick cover sits in front of and
            // completely masks the left-hand PDF page from the camera.
            hinge.position.z = isOpen ? -0.245 : 0.105
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
        frontMaterial.lightingModel = .physicallyBased
        frontMaterial.roughness.contents = 0.88
        frontMaterial.isDoubleSided = false
        frontMaterial.roughness.contents = 0.92

        // The pivot stays on the spine; the page itself is offset to the
        // fore-edge, which makes the sheet sweep across the book rather
        // than spin around its own centre.
        let hinge = SCNNode()
        hinge.position = SCNVector3(0, 0, 0.075)
        let leaf = SCNNode(geometry: SCNPlane(width: 1.49, height: 2.10))
        leaf.geometry?.materials = [frontMaterial]
        leaf.position.x = movingForward ? 0.745 : -0.745
        leaf.castsShadow = true
        leaf.renderingOrder = 10
        hinge.addChildNode(leaf)

        if let reverse {
            let backMaterial = SCNMaterial()
            backMaterial.diffuse.contents = reverse
            backMaterial.lightingModel = .physicallyBased
            backMaterial.isDoubleSided = false
            backMaterial.roughness.contents = 0.92
            let back = SCNNode(geometry: SCNPlane(width: 1.49, height: 2.10))
            back.geometry?.materials = [backMaterial]
            back.position.z = -0.002
            back.eulerAngles.y = .pi
            back.castsShadow = true
            leaf.addChildNode(back)
        }
        scene.rootNode.addChildNode(hinge)

        let flip = SCNAction.rotateTo(
            x: 0,
            y: movingForward ? -.pi : .pi,
            z: 0,
            duration: 0.92,
            usesShortestUnitArc: false
        )
        flip.timingMode = .easeInEaseOut

        // Lift the sheet off the paper block as it crosses the gutter. The
        // small roll and fore-edge compression keep the turn from looking
        // like a rigid card rotating in a flat plane.
        let curl = SCNAction.customAction(duration: 0.92) { node, elapsed in
            let progress = CGFloat(min(max(elapsed / 0.92, 0), 1))
            let lift = Float(sin(progress * .pi))
            node.position.z = 0.075 + lift * 0.34
            leaf.eulerAngles.z = Float(sin(progress * .pi)) * (movingForward ? 0.045 : -0.045)
            leaf.scale.x = 1 - Float(sin(progress * .pi)) * 0.035
        }
        curl.timingMode = .easeInEaseOut
        hinge.runAction(.group([flip, curl])) { [weak hinge] in
            DispatchQueue.main.async { hinge?.removeFromParentNode() }
        }
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        // Keep a deliberate stage behind the model if a page texture fails.
        scene.background.contents = UIColor.clear
        let root = scene.rootNode
        // A complete fireside reading set: the book is staged in a room,
        // not floating against a flat background image.
        let roomWallMaterial = SCNMaterial()
        roomWallMaterial.diffuse.contents = UIColor(red: 0.105, green: 0.061, blue: 0.043, alpha: 1)
        roomWallMaterial.roughness.contents = 0.94
        let roomWall = SCNNode(geometry: SCNBox(width: 16, height: 10, length: 0.18, chamferRadius: 0))
        roomWall.geometry?.materials = Array(repeating: roomWallMaterial, count: 6)
        roomWall.position = SCNVector3(0, 2.0, -3.15)
        root.addChildNode(roomWall)

        let stone = SCNMaterial()
        stone.diffuse.contents = UIColor(red: 0.24, green: 0.19, blue: 0.15, alpha: 1)
        stone.roughness.contents = 0.88
        let darkFirebox = SCNMaterial()
        darkFirebox.diffuse.contents = UIColor(red: 0.018, green: 0.012, blue: 0.009, alpha: 1)
        darkFirebox.roughness.contents = 1
        func roomBox(_ name: String, _ size: SCNVector3, _ position: SCNVector3, _ material: SCNMaterial, chamfer: CGFloat = 0.025) -> SCNNode {
            let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: chamfer)
            geometry.materials = Array(repeating: material, count: 6)
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = position
            root.addChildNode(node)
            return node
        }
        // Fireplace opening and heavy stone surround.
        roomBox("fireplace-shadow", SCNVector3(3.15, 1.95, 0.12), SCNVector3(-1.15, 2.12, -2.99), darkFirebox, chamfer: 0.12)
        roomBox("fireplace-left-stone", SCNVector3(0.34, 2.25, 0.34), SCNVector3(-2.90, 2.15, -2.78), stone)
        roomBox("fireplace-right-stone", SCNVector3(0.34, 2.25, 0.34), SCNVector3(0.60, 2.15, -2.78), stone)
        roomBox("fireplace-lintel", SCNVector3(3.85, 0.34, 0.42), SCNVector3(-1.15, 3.32, -2.76), stone, chamfer: 0.06)
        roomBox("fireplace-hearth", SCNVector3(4.25, 0.22, 0.72), SCNVector3(-1.15, 1.00, -2.62), stone, chamfer: 0.05)
        let mantel = SCNMaterial()
        mantel.diffuse.contents = UIColor(red: 0.16, green: 0.085, blue: 0.047, alpha: 1)
        mantel.roughness.contents = 0.38
        roomBox("walnut-mantel", SCNVector3(4.55, 0.16, 0.62), SCNVector3(-1.15, 3.56, -2.62), mantel, chamfer: 0.045)

        let ember = SCNMaterial()
        ember.diffuse.contents = UIColor(red: 0.11, green: 0.035, blue: 0.012, alpha: 1)
        ember.emission.contents = UIColor(red: 0.35, green: 0.055, blue: 0.008, alpha: 1)
        ember.roughness.contents = 1
        for index in 0..<3 {
            let log = SCNNode(geometry: SCNCylinder(radius: 0.075, height: 1.45))
            log.geometry?.materials = [ember]
            log.eulerAngles.z = index == 1 ? -.pi / 2.8 : .pi / 2.8
            log.position = SCNVector3(-1.15 + Float(index - 1) * 0.12, 1.55 + Float(index) * 0.08, -2.70)
            root.addChildNode(log)
        }
        // Individually sculpted tapered flame tongues. A stack of overlapping
        // spheres reads as plastic blobs; narrow cone meshes create a pointed
        // silhouette, with staggered motion and warm emissive cores.
        for index in 0..<7 {
            let height = CGFloat(0.48 + Double(index % 3) * 0.13)
            let width = CGFloat(0.105 + Double(index % 2) * 0.035)
            let flameMaterial = SCNMaterial()
            flameMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.19 + CGFloat(index % 3) * 0.045, blue: 0.018, alpha: 1)
            flameMaterial.emission.contents = UIColor(red: 1, green: 0.12 + CGFloat(index % 3) * 0.055, blue: 0.006, alpha: 1)
            flameMaterial.roughness.contents = 0.72
            flameMaterial.isDoubleSided = true
            let flameGeometry = SCNCone(topRadius: 0.008, bottomRadius: width, height: height)
            flameGeometry.radialSegmentCount = 18
            flameGeometry.heightSegmentCount = 8
            flameGeometry.materials = [flameMaterial]
            let flame = SCNNode(geometry: flameGeometry)
            flame.name = "fire-tongue-\\(index)"
            flame.position = SCNVector3(-1.78 + Float(index) * 0.21, 1.72 + Float(index % 2) * 0.035, -2.49 + Float(index % 3) * 0.025)
            flame.pivot = SCNMatrix4MakeTranslation(0, -Float(height) * 0.42, 0)
            flame.eulerAngles.z = Float(index - 3) * 0.11
            root.addChildNode(flame)
            let duration = 0.32 + Double(index % 4) * 0.055
            let dance = SCNAction.repeatForever(.sequence([
                .group([
                    .scale(to: CGFloat(0.78 + Double(index % 3) * 0.10), duration: duration),
                    .rotateTo(x: 0, y: 0, z: CGFloat(Float(index - 3) * 0.11 + (index % 2 == 0 ? 0.10 : -0.10)), duration: duration)
                ]),
                .group([
                    .scale(to: 1, duration: duration * 0.9),
                    .rotateTo(x: 0, y: 0, z: CGFloat(Float(index - 3) * 0.11), duration: duration * 0.9)
                ])
            ]))
            dance.timingMode = .easeInEaseOut
            flame.runAction(dance)
        }
        // Fine ember points at the base of the logs.
        for index in 0..<12 {
            let emberMaterial = SCNMaterial()
            emberMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.12, blue: 0.008, alpha: 1)
            emberMaterial.emission.contents = UIColor(red: 1, green: 0.08, blue: 0.002, alpha: 1)
            let ember = SCNNode(geometry: SCNSphere(radius: CGFloat(0.012 + Double(index % 3) * 0.006)))
            ember.geometry?.materials = [emberMaterial]
            ember.position = SCNVector3(-1.9 + Float(index) * 0.14, 1.53 + Float(index % 3) * 0.018, -2.47)
            root.addChildNode(ember)
            ember.runAction(.repeatForever(.sequence([
                .fadeOpacity(to: 0.28, duration: 0.35 + Double(index % 4) * 0.07),
                .fadeOpacity(to: 1, duration: 0.25 + Double(index % 3) * 0.06)
            ])))
        }
        let fireGlow = SCNNode()
        let fireLamp = SCNLight()
        fireLamp.type = .omni
        fireLamp.color = UIColor(red: 1, green: 0.31, blue: 0.075, alpha: 1)
        fireLamp.intensity = 850
        fireLamp.attenuationStartDistance = 0.4
        fireLamp.attenuationEndDistance = 8
        fireGlow.light = fireLamp
        fireGlow.position = SCNVector3(-1.15, 2.05, -1.95)
        root.addChildNode(fireGlow)
        let flicker = SCNAction.repeatForever(.sequence([
            .customAction(duration: 0.18) { node, elapsed in
                node.light?.intensity = 720 + CGFloat(sin(elapsed * 23) * 150 + cos(elapsed * 11) * 65)
            },
            .wait(duration: 0.04)
        ]))
        fireGlow.runAction(flicker)

        // A few dark oak wall pilasters and brass sconces establish scale.
        let oak = SCNMaterial()
        oak.diffuse.contents = UIColor(red: 0.075, green: 0.041, blue: 0.028, alpha: 1)
        oak.roughness.contents = 0.62
        roomBox("left-wall-pilaster", SCNVector3(0.13, 6.4, 0.12), SCNVector3(-5.0, 2.1, -2.98), oak)
        roomBox("right-wall-pilaster", SCNVector3(0.13, 6.4, 0.12), SCNVector3(4.6, 2.1, -2.98), oak)

        // A compact, substantial page block with a visible fore-edge.
        let paperBlock = SCNBox(width: 3.00, height: 2.18, length: 0.20, chamferRadius: 0.035)
        let blockMaterial = SCNMaterial()
        blockMaterial.diffuse.contents = paper
        blockMaterial.roughness.contents = 0.96
        paperBlock.materials = Array(repeating: blockMaterial, count: 6)
        let block = SCNNode(geometry: paperBlock)
        block.name = "paper-block"
        block.position.z = -0.105
        root.addChildNode(block)

        // Fine stacked rules on the fore-edge suggest gathered signatures.
        for index in 0..<5 {
            let ruleGeometry = SCNBox(width: 0.0025, height: 2.08, length: 0.002, chamferRadius: 0)
            let ruleMaterial = SCNMaterial()
            ruleMaterial.diffuse.contents = UIColor(red: 0.69, green: 0.63, blue: 0.52, alpha: 1)
            ruleMaterial.lightingModel = .constant
            ruleGeometry.materials = Array(repeating: ruleMaterial, count: 6)
            let rule = SCNNode(geometry: ruleGeometry)
            rule.position = SCNVector3(1.501 + Float(index) * 0.0035, 0, 0.022)
            root.addChildNode(rule)
        }

        let boardMaterial = SCNMaterial()
        boardMaterial.diffuse.contents = UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1)
        boardMaterial.roughness.contents = 0.88
        let rearBoardGeometry = SCNBox(width: 3.08, height: 2.28, length: 0.075, chamferRadius: 0.035)
        rearBoardGeometry.materials = Array(repeating: boardMaterial, count: 6)
        let rearBoard = SCNNode(geometry: rearBoardGeometry)
        rearBoard.position = SCNVector3(0, 0, -0.235)
        root.addChildNode(rearBoard)

        let spineGeometry = SCNBox(width: 0.16, height: 2.24, length: 0.25, chamferRadius: 0.07)
        spineGeometry.materials = Array(repeating: boardMaterial, count: 6)
        let spine = SCNNode(geometry: spineGeometry)
        spine.position = SCNVector3(0, 0, -0.02)
        root.addChildNode(spine)

        func pageNode(_ name: String, x: Float) -> SCNNode {
            // A tessellated leaf has a shallow gutter valley and a softly lifted
            // fore-edge. This gives the real PDF texture a paper-like silhouette.
            let columns = 18
            let rows = 30
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uv: [CGPoint] = []
            var indices: [UInt32] = []
            for row in 0...rows {
                let v = Float(row) / Float(rows)
                for column in 0...columns {
                    let u = Float(column) / Float(columns)
                    let localX = u * 1.49
                    let gutter = sin(u * .pi) * 0.045
                    let edgeLift = pow(u, 2.4) * 0.035
                    let verticalBow = pow(abs(v - 0.5) * 2, 2) * 0.012
                    let z = gutter + edgeLift + verticalBow
                    let sideX = x < 0 ? -localX : localX
                    vertices.append(SCNVector3(sideX, (0.5 - v) * 2.10, z))
                    normals.append(SCNVector3(0, 0, 1))
                    uv.append(CGPoint(x: CGFloat(x < 0 ? 1 - u : u), y: CGFloat(v)))
                }
            }
            for row in 0..<rows {
                for column in 0..<columns {
                    let a = UInt32(row * (columns + 1) + column)
                    let b = a + 1
                    let c = a + UInt32(columns + 1)
                    let d = c + 1
                    indices.append(contentsOf: [a, c, b, b, c, d])
                }
            }
            let vertexSource = SCNGeometrySource(vertices: vertices)
            let normalSource = SCNGeometrySource(normals: normals)
            let uvSource = SCNGeometrySource(textureCoordinates: uv)
            let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<UInt32>.size)
            let mesh = SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [element])
            let material = SCNMaterial()
            material.diffuse.contents = paper
            material.isDoubleSided = true
            material.lightingModel = .constant
            material.roughness.contents = 1.0
            material.metalness.contents = 0
            mesh.materials = [material]
            let node = SCNNode(geometry: mesh)
            node.name = name
            node.position.z = 0.165
            node.castsShadow = true
            node.renderingOrder = 10
            root.addChildNode(node)
            return node
        }
        // The leaves must meet at the spine and remain inside the hardback boards.
        // The old +/-1.45 offsets pushed both pages outside the book footprint.
        pageNode("left-page", x: -0.755)
        pageNode("right-page", x: 0.755)

        let hinge = SCNNode()
        hinge.name = "cover-hinge"
        hinge.position = SCNVector3(0, 0, 0.105)
        let frontBoardGeometry = SCNBox(width: 1.54, height: 2.28, length: 0.075, chamferRadius: 0.035)
        frontBoardGeometry.materials = Array(repeating: boardMaterial, count: 6)
        let frontBoard = SCNNode(geometry: frontBoardGeometry)
        frontBoard.position.x = 1.54
        hinge.addChildNode(frontBoard)

        let coverPlane = SCNPlane(width: 1.49, height: 2.14)
        let coverMaterial = SCNMaterial()
        coverMaterial.diffuse.contents = cover ?? paper
        coverMaterial.isDoubleSided = true
        coverMaterial.roughness.contents = 0.9
        coverMaterial.lightingModel = .lambert
        coverPlane.materials = [coverMaterial]
        let coverNode = SCNNode(geometry: coverPlane)
        coverNode.name = "front-cover"
        coverNode.position = SCNVector3(0.77, 0, 0.039)
        hinge.addChildNode(coverNode)
        root.addChildNode(hinge)

        let gutterGeometry = SCNBox(width: 0.075, height: 2.08, length: 0.012, chamferRadius: 0.018)
        let gutterMaterial = SCNMaterial()
        gutterMaterial.diffuse.contents = UIColor(white: 0.25, alpha: 1)
        gutterMaterial.lightingModel = .constant
        gutterGeometry.materials = Array(repeating: gutterMaterial, count: 6)
        let gutter = SCNNode(geometry: gutterGeometry)
        gutter.position = SCNVector3(0, 0, 0.171)
        root.addChildNode(gutter)

        // Dark walnut reading table: a broad physical surface catches the
        // book's shadow and anchors the object in the room.
        let deskMaterial = SCNMaterial()
        deskMaterial.diffuse.contents = UIColor(red: 0.105, green: 0.061, blue: 0.038, alpha: 1)
        deskMaterial.roughness.contents = 0.42
        deskMaterial.metalness.contents = 0.04
        let deskGeometry = SCNBox(width: 12, height: 0.16, length: 8, chamferRadius: 0.04)
        deskGeometry.materials = Array(repeating: deskMaterial, count: 6)
        let desk = SCNNode(geometry: deskGeometry)
        desk.position = SCNVector3(0, -1.18, -0.46)
        desk.castsShadow = false
        root.addChildNode(desk)

        // Fine brass tooling on the front board edge and a dark cloth spine.
        let foilMaterial = SCNMaterial()
        foilMaterial.diffuse.contents = UIColor(red: 0.69, green: 0.48, blue: 0.25, alpha: 1)
        foilMaterial.metalness.contents = 0.72
        foilMaterial.roughness.contents = 0.32
        foilMaterial.lightingModel = .physicallyBased
        for y in [-1.05 as Float, 1.05 as Float] {
            let rule = SCNNode(geometry: SCNBox(width: 2.88, height: 0.012, length: 0.004, chamferRadius: 0.002))
            rule.geometry?.materials = [foilMaterial]
            rule.position = SCNVector3(0, y, 0.205)
            root.addChildNode(rule)
        }

        let ambient = SCNNode()
        let ambientLamp = SCNLight()
        ambientLamp.type = .ambient
        ambientLamp.intensity = 120
        ambientLamp.color = UIColor(red: 0.78, green: 0.72, blue: 0.63, alpha: 1)
        ambient.light = ambientLamp
        root.addChildNode(ambient)

        let light = SCNNode()
        let lamp = SCNLight()
        lamp.type = .directional
        lamp.intensity = 420
        lamp.color = UIColor(red: 1, green: 0.88, blue: 0.69, alpha: 1)
        lamp.castsShadow = true
        lamp.shadowRadius = 12
        lamp.shadowColor = UIColor.black.withAlphaComponent(0.42)
        lamp.shadowMode = .deferred
        light.light = lamp
        light.eulerAngles = SCNVector3(-0.58, -0.42, 0)
        root.addChildNode(light)

        let fill = SCNNode()
        let fillLamp = SCNLight()
        fillLamp.type = .omni
        fillLamp.intensity = 90
        fillLamp.color = UIColor(red: 0.72, green: 0.79, blue: 0.88, alpha: 1)
        fill.light = fillLamp
        fill.position = SCNVector3(2.4, -1.5, 3.5)
        root.addChildNode(fill)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 100
        camera.wantsHDR = true
        camera.bloomIntensity = 0.12
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "folio-camera"
        cameraNode.position = SCNVector3(0.04, 0.78, 8.4)
        cameraNode.look(at: SCNVector3(0, 0, 0))
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
