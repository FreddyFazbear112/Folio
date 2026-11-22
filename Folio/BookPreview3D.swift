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
        let front = material(tint)
        loadArtwork(coverURL, into: front)
        let back = material(tint)
        loadArtwork(backCoverURL, into: back)
        book.materials = [
            material(tint), material(UIColor(red: 0.82, green: 0.77, blue: 0.67, alpha: 1)),
            material(tint.withAlphaComponent(0.85)), material(tint), front, back
        ]
        let node = SCNNode(geometry: book)
        node.position = SCNVector3(0, 0, 0)
        node.eulerAngles = SCNVector3(0.12, -0.48, 0.06)
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: book, options: nil))
        body.mass = 0.65
        body.angularDamping = 1.7
        body.damping = 0.8
        body.isAffectedByGravity = false
        node.physicsBody = body
        body.applyTorque(SCNVector4(0, 1, 0, 0.35), asImpulse: true)
        scene.rootNode.addChildNode(node)

        if coverURL == nil {
            let titleText = SCNText(string: title.uppercased(), extrusionDepth: 0.002)
            titleText.font = UIFont(name: "Georgia", size: 7)
            titleText.flatness = 0.2
            titleText.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: titleText)
            textNode.scale = SCNVector3(0.012, 0.012, 0.012)
            textNode.position = SCNVector3(-0.47, -0.12, 0.116)
            node.addChildNode(textNode)
        }

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.2)
        scene.rootNode.addChildNode(cameraNode)
        return scene
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
