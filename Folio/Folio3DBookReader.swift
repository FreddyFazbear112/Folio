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
        GeometryReader { proxy in
            ZStack {
                // The 3D lounge is the actual full-screen reading environment.
                // The old 500pt stage left the lower half of the phone as dead black UI space.
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
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                        guard isOpen else { withAnimation(.easeInOut(duration: 0.8)) { isOpen = true }; return }
                        if value.translation.width < -35 { turn(1) }
                        if value.translation.width > 35 { turn(-1) }
                    })
                    .ignoresSafeArea()
                } else {
                    ZStack {
                        Color(red: 0.035, green: 0.022, blue: 0.016)
                        Image("ReadingRoom").resizable().scaledToFill().opacity(0.22)
                    }.ignoresSafeArea()
                }

                // Subtle cinematic vignette keeps text legible without burying
                // the modeled architecture in a black gradient.
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.58), location: 0),
                        .init(color: Color.clear, location: 0.23),
                        .init(color: Color.clear, location: 0.72),
                        .init(color: Color.black.opacity(0.72), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down").font(.system(size: 14, weight: .semibold))
                                .frame(width: 42, height: 42).background(.white.opacity(0.10), in: Circle())
                        }
                        Spacer()
                        VStack(spacing: 3) {
                            Text("FOLIO").font(.system(size: 9, weight: .bold)).tracking(2.5)
                            Text(title).font(.system(size: 14, design: .serif)).lineLimit(1)
                        }
                        Spacer()
                        Button { sepia.toggle(); refreshScene() } label: {
                            Image(systemName: sepia ? "moon" : "sun.max").font(.system(size: 14))
                                .frame(width: 42, height: 42).background(.white.opacity(0.10), in: Circle())
                        }
                    }
                    .foregroundStyle(Color(red: 0.96, green: 0.90, blue: 0.78))
                    .padding(.horizontal, 20).padding(.top, proxy.safeAreaInsets.top + 8)

                    HStack(alignment: .lastTextBaseline) {
                        Text("NOW READING").font(.system(size: 8, weight: .bold)).tracking(2.2)
                            .foregroundStyle(Color(red: 0.90, green: 0.69, blue: 0.43))
                        Spacer()
                        Text(isOpen ? "OPEN EDITION" : "CLOTHBOUND EDITION")
                            .font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.62))
                    }
                    .padding(.horizontal, 25).padding(.top, 16)

                    if let loadError {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.ellipsis").font(.system(size: 30, weight: .ultraLight))
                            Text("This reading copy couldn't be opened").font(.system(size: 18, design: .serif))
                            Text(loadError).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                        }.foregroundStyle(.white).padding(.horizontal, 30)
                        Spacer()
                    } else if document == nil {
                        Spacer()
                        ProgressView("Preparing your book…").tint(.white).foregroundStyle(.white)
                        Spacer()
                    } else {
                        Spacer(minLength: 0)
                        VStack(spacing: 14) {
                            HStack(spacing: 34) {
                                Button { turn(-1) } label: { Image(systemName: "chevron.left") }
                                    .disabled(!isOpen || page <= 1)
                                Text(total > 0 ? "PAGE \\(page) OF \\(total)" : "OPENING")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.4)
                                Button { turn(1) } label: { Image(systemName: "chevron.right") }
                                    .disabled(!isOpen || page >= total)
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(red: 0.96, green: 0.79, blue: 0.54))
                            .padding(.vertical, 8)
                            if total > 0 {
                                ProgressView(value: Double(page), total: Double(total))
                                    .tint(Color(red: 0.82, green: 0.64, blue: 0.39))
                            }
                            Text(isOpen ? "SWIPE TO TURN THE PAGE" : "TAP THE COVER TO OPEN YOUR BOOK")
                                .font(.system(size: 8, weight: .medium)).tracking(1.8)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18) + 12)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
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

        // Runtime-built high-resolution surface maps. These are actual material
        // textures (not flat color swatches): directional wood grain, mottled
        // stone, woven cloth and leather pores, generated once per scene.
        func surfaceMap(_ size: Int = 1024, base: UIColor, kind: Int, seed: CGFloat) -> UIImage {
            let canvas = CGSize(width: size, height: size)
            return UIGraphicsImageRenderer(size: canvas).image { renderer in
                let ctx = renderer.cgContext
                ctx.setFillColor(base.cgColor)
                ctx.fill(CGRect(origin: .zero, size: canvas))
                func wave(_ value: CGFloat) -> CGFloat { (sin(value * 12.9898 + seed * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude }
                if kind == 0 { // sawn walnut
                    for line in 0..<520 {
                        let y = CGFloat(line) * canvas.height / 520
                        let phase = CGFloat(line) * 0.071 + seed
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: 0, y: y))
                        for step in 0...32 {
                            let x = CGFloat(step) * canvas.width / 32
                            let yy = y + sin(x * 0.012 + phase) * (2 + wave(phase) * 7)
                            path.addLine(to: CGPoint(x: x, y: yy))
                        }
                        let alpha = 0.035 + wave(phase) * 0.10
                        UIColor(white: wave(phase) > 0.5 ? 0.02 : 0.95, alpha: alpha).setStroke()
                        path.lineWidth = 0.7 + wave(phase + 1) * 2.4
                        path.stroke()
                    }
                    for knot in 0..<5 {
                        let x = wave(CGFloat(knot) + seed) * canvas.width
                        let y = wave(CGFloat(knot) * 2 + seed) * canvas.height
                        for ring in 0..<8 {
                            let radius = CGFloat(ring + 1) * (5 + wave(CGFloat(knot)) * 3)
                            let oval = UIBezierPath(ovalIn: CGRect(x: x - radius * 1.8, y: y - radius * 0.55, width: radius * 3.6, height: radius * 1.1))
                            UIColor(white: 0.02, alpha: 0.045).setStroke()
                            oval.lineWidth = 1
                            oval.stroke()
                        }
                    }
                } else if kind == 1 { // limestone / hand-cut stone
                    for i in 0..<18000 {
                        let x = wave(CGFloat(i) * 1.13 + seed) * canvas.width
                        let y = wave(CGFloat(i) * 2.31 + seed * 2) * canvas.height
                        let radius = 0.6 + wave(CGFloat(i) * 3.7) * (kind == 1 ? 5 : 2)
                        let alpha = 0.025 + wave(CGFloat(i) * 5.1) * 0.11
                        UIColor(white: wave(CGFloat(i) * 7.7) > 0.5 ? 1 : 0, alpha: alpha).setFill()
                        ctx.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
                    }
                    for seam in 0..<18 {
                        let y = CGFloat(seam) * canvas.height / 18 + wave(CGFloat(seam) + seed) * 18
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: canvas.width, y: y + wave(CGFloat(seam) * 4) * 12 - 6))
                        UIColor(white: 0.04, alpha: 0.12).setStroke()
                        p.lineWidth = 2
                        p.stroke()
                    }
                } else { // upholstery / book cloth / leather grain
                    for i in 0..<22000 {
                        let x = wave(CGFloat(i) * 1.13 + seed) * canvas.width
                        let y = wave(CGFloat(i) * 2.31 + seed * 2) * canvas.height
                        let alpha = 0.025 + wave(CGFloat(i) * 3.7) * 0.075
                        UIColor(white: wave(CGFloat(i) * 5.1) > 0.5 ? 1 : 0, alpha: alpha).setFill()
                        ctx.fillEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                    }
                    for line in stride(from: 0, to: size, by: 8) {
                        let p = UIBezierPath()
                        p.move(to: CGPoint(x: line, y: 0))
                        p.addLine(to: CGPoint(x: line, y: size))
                        UIColor(white: 0.5, alpha: 0.035).setStroke()
                        p.lineWidth = 1
                        p.stroke()
                    }
                }
            }
        }
        let walnutMap = surfaceMap(base: UIColor(red: 0.19, green: 0.095, blue: 0.052, alpha: 1), kind: 0, seed: 3.1)
        let stoneMap = surfaceMap(base: UIColor(red: 0.34, green: 0.27, blue: 0.21, alpha: 1), kind: 1, seed: 7.4)
        let clothMap = surfaceMap(base: UIColor(red: 0.17, green: 0.055, blue: 0.043, alpha: 1), kind: 2, seed: 11.2)
        func applyMap(_ image: UIImage, to material: SCNMaterial) {
            material.diffuse.contents = image
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.magnificationFilter = .linear
            material.diffuse.minificationFilter = .linear
            material.roughness.contents = 0.78
        }
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
        applyMap(stoneMap, to: stone)
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
        applyMap(walnutMap, to: mantel)
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
        // A flame is a curved, tapered volumetric mesh with an uneven centreline,
        // not a cone. The changing cross-section gives it a living silhouette.
        func flameTongue(width: CGFloat, height: CGFloat, phase: CGFloat, material: SCNMaterial) -> SCNGeometry {
            let rings = 22
            let segments = 14
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var indices: [UInt32] = []
            for ring in 0...rings {
                let t = CGFloat(ring) / CGFloat(rings)
                let envelope = pow(max(0, sin(t * .pi)), 0.72)
                let radius = width * envelope * (1 - t * 0.26)
                let drift = sin(t * 5.2 + phase) * width * 0.38 * t
                for segment in 0...segments {
                    let angle = CGFloat(segment) / CGFloat(segments) * .pi * 2
                    let cx = drift + cos(angle) * radius
                    let cz = sin(angle) * radius * 0.42
                    vertices.append(SCNVector3(Float(cx), Float(t * height), Float(cz)))
                    normals.append(SCNVector3(Float(cos(angle)), 0.25, Float(sin(angle) * 1.8)))
                    uvs.append(CGPoint(x: CGFloat(segment) / CGFloat(segments), y: t))
                }
            }
            for ring in 0..<rings {
                for segment in 0..<segments {
                    let a = UInt32(ring * (segments + 1) + segment)
                    let b = a + 1
                    let c = a + UInt32(segments + 1)
                    let d = c + 1
                    indices.append(contentsOf: [a, b, c, b, d, c])
                }
            }
            let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<UInt32>.size)
            let geometry = SCNGeometry(sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ], elements: [element])
            geometry.materials = [material]
            return geometry
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
            let flameGeometry = flameTongue(width: width, height: height, phase: CGFloat(index) * 0.83, material: flameMaterial)
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
        applyMap(walnutMap, to: oak)
        roomBox("left-wall-pilaster", SCNVector3(0.13, 6.4, 0.12), SCNVector3(-5.0, 2.1, -2.98), oak)
        roomBox("right-wall-pilaster", SCNVector3(0.13, 6.4, 0.12), SCNVector3(4.6, 2.1, -2.98), oak)

        // Full reading-lounge architecture: floor, wainscoting, ceiling beams,
        // built-in bookcases, a moonlit window and a layered Persian-style rug.
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.105, green: 0.061, blue: 0.041, alpha: 1)
        floorMat.roughness.contents = 0.76
        applyMap(walnutMap, to: floorMat)
        roomBox("room-floor", SCNVector3(18, 0.16, 13), SCNVector3(0, -1.56, -0.35), floorMat, chamfer: 0.01)

        let panelMat = SCNMaterial()
        panelMat.diffuse.contents = UIColor(red: 0.12, green: 0.066, blue: 0.042, alpha: 1)
        panelMat.roughness.contents = 0.68
        applyMap(walnutMap, to: panelMat)
        roomBox("lower-wall-wainscot", SCNVector3(15.8, 1.18, 0.12), SCNVector3(0, 0.05, -3.02), panelMat)
        for x in stride(from: -4.5 as Float, through: 4.5, by: 0.75) {
            roomBox("wall-panel-stile", SCNVector3(0.025, 1.0, 0.035), SCNVector3(x, 0.04, -2.93), mantel, chamfer: 0.006)
        }
        roomBox("chair-rail", SCNVector3(15.8, 0.055, 0.11), SCNVector3(0, 0.68, -2.91), mantel)
        roomBox("baseboard", SCNVector3(15.8, 0.12, 0.13), SCNVector3(0, -0.56, -2.90), oak)

        let rugBase = SCNMaterial()
        rugBase.diffuse.contents = UIColor(red: 0.19, green: 0.055, blue: 0.035, alpha: 1)
        rugBase.roughness.contents = 1
        roomBox("rug-underlay", SCNVector3(7.4, 0.025, 4.2), SCNVector3(0, -1.445, 0.25), rugBase, chamfer: 0.10)
        let rugBorder = SCNMaterial()
        rugBorder.diffuse.contents = UIColor(red: 0.62, green: 0.39, blue: 0.18, alpha: 1)
        rugBorder.metalness.contents = 0.12
        rugBorder.roughness.contents = 0.8
        for z in [-1.68 as Float, 2.18 as Float] {
            roomBox("rug-border-long", SCNVector3(7.0, 0.008, 0.025), SCNVector3(0, -1.428, z), rugBorder, chamfer: 0.004)
        }
        for x in [-3.48 as Float, 3.48 as Float] {
            roomBox("rug-border-short", SCNVector3(0.025, 0.008, 3.86), SCNVector3(x, -1.428, 0.25), rugBorder, chamfer: 0.004)
        }

        // Built-in library bays flanking the hearth. Each book is a separate
        // clothbound volume with varied height, spine color and subtle foil.
        let shelfWood = SCNMaterial()
        shelfWood.diffuse.contents = UIColor(red: 0.105, green: 0.052, blue: 0.031, alpha: 1)
        shelfWood.roughness.contents = 0.42
        applyMap(walnutMap, to: shelfWood)
        let bookPalette: [UIColor] = [
            UIColor(red: 0.24, green: 0.075, blue: 0.055, alpha: 1),
            UIColor(red: 0.12, green: 0.17, blue: 0.16, alpha: 1),
            UIColor(red: 0.32, green: 0.20, blue: 0.095, alpha: 1),
            UIColor(red: 0.17, green: 0.105, blue: 0.16, alpha: 1),
            UIColor(red: 0.34, green: 0.29, blue: 0.19, alpha: 1)
        ]
        for side in [-1 as Float, 1 as Float] {
            let shelfX = side * 3.05
            roomBox("bookcase-side", SCNVector3(1.05, 4.55, 0.48), SCNVector3(shelfX, 1.65, -2.72), shelfWood, chamfer: 0.035)
            for level in 0..<4 {
                let y = 0.05 + Float(level) * 1.05
                roomBox("bookcase-shelf", SCNVector3(1.18, 0.075, 0.62), SCNVector3(shelfX, y, -2.42), mantel, chamfer: 0.018)
                for item in 0..<7 {
                    let height = 0.48 + Float((item + level) % 4) * 0.10
                    let width = 0.095 + Float(item % 2) * 0.025
                    let material = SCNMaterial()
                    material.diffuse.contents = bookPalette[(item + level * 2) % bookPalette.count]
                    material.roughness.contents = 0.82
                    let book = SCNNode(geometry: SCNBox(width: CGFloat(width), height: CGFloat(height), length: 0.30, chamferRadius: 0.012))
                    book.geometry?.materials = [material]
                    book.position = SCNVector3(shelfX - 0.47 + Float(item) * 0.145, y + 0.055 + height / 2, -2.40)
                    book.eulerAngles.z = Float(item % 3 - 1) * 0.035
                    root.addChildNode(book)
                    let gilt = SCNMaterial()
                    gilt.diffuse.contents = UIColor(red: 0.68, green: 0.48, blue: 0.23, alpha: 1)
                    gilt.emission.contents = UIColor(red: 0.10, green: 0.045, blue: 0.012, alpha: 1)
                    for offset in [-0.16 as Float, 0.16 as Float] {
                        let band = SCNNode(geometry: SCNBox(width: CGFloat(width * 0.76), height: 0.012, length: 0.006, chamferRadius: 0))
                        band.geometry?.materials = [gilt]
                        band.position = SCNVector3(book.position.x, book.position.y + offset * min(height, 0.8), -2.238)
                        root.addChildNode(band)
                    }
                }
            }
        }

        // A tall mullioned window gives the room a cool secondary light source.
        let windowFrame = SCNMaterial()
        windowFrame.diffuse.contents = UIColor(red: 0.12, green: 0.075, blue: 0.05, alpha: 1)
        windowFrame.roughness.contents = 0.38
        let nightGlass = SCNMaterial()
        nightGlass.diffuse.contents = UIColor(red: 0.018, green: 0.035, blue: 0.075, alpha: 1)
        nightGlass.emission.contents = UIColor(red: 0.012, green: 0.025, blue: 0.065, alpha: 1)
        nightGlass.roughness.contents = 0.18
        roomBox("window-night", SCNVector3(1.42, 2.35, 0.045), SCNVector3(1.68, 2.25, -3.00), nightGlass, chamfer: 0.025)
        for x in [0.94 as Float, 1.68, 2.42] {
            roomBox("window-mullion", SCNVector3(0.075, 2.52, 0.12), SCNVector3(x, 2.25, -2.91), windowFrame)
        }
        for y in [1.05 as Float, 2.25, 3.45] {
            roomBox("window-crossbar", SCNVector3(1.58, 0.075, 0.12), SCNVector3(1.68, y, -2.91), windowFrame)
        }
        let moonMat = SCNMaterial()
        moonMat.diffuse.contents = UIColor(red: 0.66, green: 0.72, blue: 0.82, alpha: 1)
        moonMat.emission.contents = UIColor(red: 0.16, green: 0.20, blue: 0.30, alpha: 1)
        let moon = SCNNode(geometry: SCNSphere(radius: 0.16))
        moon.geometry?.materials = [moonMat]
        moon.position = SCNVector3(2.05, 2.86, -2.86)
        root.addChildNode(moon)

        // Reading chair and side table sit behind the book, grounding the lounge.
        let leather = SCNMaterial()
        leather.diffuse.contents = UIColor(red: 0.16, green: 0.045, blue: 0.035, alpha: 1)
        leather.roughness.contents = 0.58
        applyMap(clothMap, to: leather)
        let chair = roomBox("reading-chair-seat", SCNVector3(1.55, 0.34, 1.05), SCNVector3(2.0, -0.82, -1.25), leather, chamfer: 0.16)
        chair.eulerAngles.y = -0.18
        roomBox("reading-chair-back", SCNVector3(1.55, 1.42, 0.32), SCNVector3(2.0, -0.12, -1.72), leather, chamfer: 0.20)
        for side in [-1 as Float, 1 as Float] {
            roomBox("chair-arm", SCNVector3(0.25, 0.64, 0.92), SCNVector3(2.0 + side * 0.78, -0.48, -1.25), leather, chamfer: 0.11)
        }
        roomBox("side-table-top", SCNVector3(0.82, 0.10, 0.72), SCNVector3(-2.45, -0.72, -1.45), mantel, chamfer: 0.035)
        for x in [-2.76 as Float, -2.14 as Float] {
            roomBox("side-table-leg", SCNVector3(0.07, 0.78, 0.07), SCNVector3(x, -1.12, -1.45), shelfWood)
        }
        let shade = SCNMaterial()
        shade.diffuse.contents = UIColor(red: 0.72, green: 0.52, blue: 0.28, alpha: 1)
        shade.emission.contents = UIColor(red: 0.10, green: 0.055, blue: 0.02, alpha: 1)
        let lampShade = SCNNode(geometry: SCNCone(topRadius: 0.18, bottomRadius: 0.32, height: 0.42))
        lampShade.geometry?.materials = [shade]
        lampShade.position = SCNVector3(-2.45, -0.10, -1.45)
        root.addChildNode(lampShade)
        let lampNode = SCNNode()
        let readingLamp = SCNLight()
        readingLamp.type = .omni
        readingLamp.color = UIColor(red: 1, green: 0.72, blue: 0.42, alpha: 1)
        readingLamp.intensity = 260
        readingLamp.attenuationEndDistance = 4
        lampNode.light = readingLamp
        lampNode.position = SCNVector3(-2.45, -0.35, -1.25)
        root.addChildNode(lampNode)

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
        applyMap(walnutMap, to: deskMaterial)
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
