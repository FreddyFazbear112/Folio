import SwiftUI
import SceneKit

struct BookPreview3D: UIViewRepresentable {
    let title: String
    let tint: UIColor

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
        view.scene = makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        view.scene = makeScene()
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        let book = SCNBox(width: 1.05, height: 1.48, length: 0.22, chamferRadius: 0.035)
        book.materials = [
            material(tint), material(UIColor(red: 0.82, green: 0.77, blue: 0.67, alpha: 1)),
            material(tint.withAlphaComponent(0.85)), material(tint), material(tint), material(tint)
        ]
        let node = SCNNode(geometry: book)
        node.position = SCNVector3(0, 0, 0)
        node.eulerAngles = SCNVector3(0.12, -0.48, 0.06)
        let spin = SCNAction.repeatForever(.sequence([
            .rotateBy(x: 0, y: 0.16, z: 0, duration: 1.8),
            .rotateBy(x: 0, y: -0.16, z: 0, duration: 1.8)
        ]))
        node.runAction(spin)
        scene.rootNode.addChildNode(node)

        let titleText = SCNText(string: title.uppercased(), extrusionDepth: 0.002)
        titleText.font = UIFont(name: "Georgia", size: 7)
        titleText.flatness = 0.2
        titleText.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: titleText)
        textNode.scale = SCNVector3(0.012, 0.012, 0.012)
        textNode.position = SCNVector3(-0.47, -0.12, 0.116)
        textNode.constraints = [SCNBillboardConstraint()]
        node.addChildNode(textNode)

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.2)
        scene.rootNode.addChildNode(cameraNode)
        return scene
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = 0.72
        return material
    }
}
