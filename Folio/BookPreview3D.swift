import SwiftUI
import SceneKit
import UIKit

struct BookPreview3D: UIViewRepresentable {
    let title: String
    let tint: UIColor
    var coverURL: String? = nil
    var backCoverURL: String? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
        view.scene = makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        context.coordinator.view = view
        context.coordinator.signature = signature
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapBook(_:))))
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if context.coordinator.signature != signature {
            view.scene = makeScene()
            context.coordinator.signature = signature
        }
    }

    private var signature: String { [title, coverURL ?? "", backCoverURL ?? ""].joined(separator: "|") }
    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.physicsWorld.gravity = SCNVector3(0, 0, 0)
        let book = SCNBox(width: 1.05, height: 1.48, length: 0.22, chamferRadius: 0.035)
        book.materials = [
            material(tint), material(UIColor(red: 0.82, green: 0.77, blue: 0.67, alpha: 1)),
            material(tint.withAlphaComponent(0.85)), material(tint), material(tint), material(tint)
        ]
        let node = SCNNode(geometry: book)
        node.position = SCNVector3(0, 0, 0)
        node.eulerAngles = SCNVector3(0.12, -0.48, 0.06)

        // A dedicated cover plane is more reliable than relying on SCNBox face
        // texture ordering. It also gives us a designed fallback when a catalogue
        // image is missing or unavailable.
        let cover = SCNPlane(width: 1.00, height: 1.43)
        let coverMaterial = SCNMaterial()
        coverMaterial.diffuse.contents = fallbackCover()
        coverMaterial.isDoubleSided = true
        coverMaterial.lightingModel = .constant
        cover.materials = [coverMaterial]
        let coverNode = SCNNode(geometry: cover)
        coverNode.position = SCNVector3(0, 0, 0.114)
        node.addChildNode(coverNode)
        loadCoverArtwork(coverURL, into: coverMaterial)

        if let backCoverURL {
            let backPlane = SCNPlane(width: 1.00, height: 1.43)
            let backMaterial = SCNMaterial()
            backMaterial.diffuse.contents = fallbackCover(isBack: true)
            backMaterial.isDoubleSided = true
            backMaterial.lightingModel = .constant
            backPlane.materials = [backMaterial]
            let backNode = SCNNode(geometry: backPlane)
            backNode.position = SCNVector3(0, 0, -0.114)
            backNode.eulerAngles.y = .pi
            node.addChildNode(backNode)
            loadCoverArtwork(backCoverURL, into: backMaterial)
        }
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: book, options: nil))
        body.mass = 0.65
        body.angularDamping = 1.7
        body.damping = 0.8
        body.isAffectedByGravity = false
        node.physicsBody = body
        body.applyTorque(SCNVector4(0, 1, 0, 0.35), asImpulse: true)
        scene.rootNode.addChildNode(node)



        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.2)
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private func loadCoverArtwork(_ address: String?, into material: SCNMaterial) {
        guard let address, let url = URL(string: address), url.scheme == "https" else { return }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data, let image = UIImage(data: data),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            DispatchQueue.main.async { material.diffuse.contents = image }
        }.resume()
    }

    private func fallbackCover(isBack: Bool = false) -> UIImage {
        let size = CGSize(width: 600, height: 860)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = isBack
                ? [UIColor(red: 0.31, green: 0.23, blue: 0.20, alpha: 1), UIColor(red: 0.20, green: 0.17, blue: 0.15, alpha: 1)]
                : [tint, tint.withAlphaComponent(0.78)]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let inset = CGRect(x: 38, y: 38, width: size.width - 76, height: size.height - 76)
            UIColor.white.withAlphaComponent(0.55).setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.stroke(inset)
            if !isBack {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineSpacing = 8
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Georgia", size: 43) ?? UIFont.systemFont(ofSize: 43, weight: .regular),
                    .foregroundColor: UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1),
                    .paragraphStyle: paragraph
                ]
                let authorAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.78),
                    .kern: 3
                ]
                title.draw(in: CGRect(x: 70, y: 245, width: 460, height: 300), withAttributes: titleAttributes)
                "A BOOK TO KEEP".draw(in: CGRect(x: 70, y: 690, width: 460, height: 35), withAttributes: authorAttributes)
            }
        }
    }

    private func loadArtwork(_ address: String?, into material: SCNMaterial) {
        guard let address, let url = URL(string: address), url.scheme == "https" else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { material.diffuse.contents = image }
        }.resume()
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = 0.72
        return material
    }

    final class Coordinator: NSObject {
        weak var view: SCNView?
        var signature = ""

        @objc func tapBook(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let point = recognizer.location(in: view)
            guard let hit = view.hitTest(point, options: nil).first?.node else { return }
            let bookNode = hit.physicsBody == nil ? hit.parent : hit
            bookNode?.physicsBody?.applyTorque(SCNVector4(0, 1, 0, 1.1), asImpulse: true)
            bookNode?.physicsBody?.applyForce(SCNVector3(0, 0.12, 0), asImpulse: true)
        }
    }
}
