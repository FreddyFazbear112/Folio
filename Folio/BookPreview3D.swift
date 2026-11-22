import SwiftUI
import SceneKit
import UIKit

/// A tactile, proportionally modelled hardback. The page block, boards, spine
/// and printed jackets are separate meshes so the book reads as an object,
/// not a single textured cuboid.
struct BookPreview3D: UIViewRepresentable {
    let title: String
    let tint: UIColor
    var coverURL: String? = nil
    var backCoverURL: String? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.955, green: 0.936, blue: 0.888, alpha: 1)
        view.scene = makeScene()
        view.allowsCameraControl = true
        view.cameraControlConfiguration.allowsTranslation = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        context.coordinator.view = view
        context.coordinator.signature = signature
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapBook(_:))))
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard context.coordinator.signature != signature else { return }
        view.scene = makeScene()
        context.coordinator.signature = signature
    }

    private var signature: String {
        [title, coverURL ?? "", backCoverURL ?? "", tint.description].joined(separator: "|")
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.955, green: 0.936, blue: 0.888, alpha: 1)

        let book = SCNNode()
        book.name = "folio-book"
        book.eulerAngles = SCNVector3(0.10, -0.43, 0.035)

        // The warm paper block sits just inside the cover boards.
        let pages = SCNBox(width: 0.975, height: 1.395, length: 0.174, chamferRadius: 0.012)
        pages.materials = [
            pageMaterial(), pageMaterial(), pageMaterial(),
            pageMaterial(), pageMaterial(), pageMaterial()
        ]
        let pageNode = SCNNode(geometry: pages)
        pageNode.position = SCNVector3(0.012, 0, 0)
        book.addChildNode(pageNode)

        // Front and rear boards create the subtle overhang of a real hardback.
        let board = SCNBox(width: 1.055, height: 1.485, length: 0.025, chamferRadius: 0.018)
        board.materials = Array(repeating: coverMaterial(), count: 6)
        let frontBoard = SCNNode(geometry: board)
        frontBoard.position = SCNVector3(0, 0, 0.103)
        book.addChildNode(frontBoard)

        let rearBoard = SCNNode(geometry: board)
        rearBoard.position = SCNVector3(0, 0, -0.103)
        book.addChildNode(rearBoard)

        // The spine is a distinct rounded piece, visible at the left edge.
        let spine = SCNBox(width: 0.055, height: 1.47, length: 0.222, chamferRadius: 0.022)
        spine.materials = Array(repeating: coverMaterial(), count: 6)
        let spineNode = SCNNode(geometry: spine)
        spineNode.position = SCNVector3(-0.515, 0, 0)
        book.addChildNode(spineNode)

        let front = SCNPlane(width: 1.035, height: 1.465)
        let frontPrint = SCNMaterial()
        frontPrint.diffuse.contents = fallbackCover()
        frontPrint.lightingModel = .constant
        frontPrint.isDoubleSided = true
        front.materials = [frontPrint]
        let frontNode = SCNNode(geometry: front)
        frontNode.position = SCNVector3(0, 0, 0.117)
        book.addChildNode(frontNode)
        loadCoverArtwork(coverURL, into: frontPrint)

        let back = SCNPlane(width: 1.035, height: 1.465)
        let backPrint = SCNMaterial()
        backPrint.diffuse.contents = fallbackCover(isBack: true)
        backPrint.lightingModel = .constant
        backPrint.isDoubleSided = true
        back.materials = [backPrint]
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, 0, -0.117)
        backNode.eulerAngles.y = .pi
        book.addChildNode(backNode)
        loadCoverArtwork(backCoverURL, into: backPrint)

        // Fine page-edge rules catch the light along the top and fore edge.
        let pageRule = SCNBox(width: 0.91, height: 0.003, length: 0.001, chamferRadius: 0)
        pageRule.materials = Array(repeating: ruleMaterial(), count: 6)
        for offset in [-0.004, 0.0, 0.004] {
            let rule = SCNNode(geometry: pageRule)
            rule.position = SCNVector3(0.012, 0.704 + offset, 0)
            book.addChildNode(rule)
        }

        scene.rootNode.addChildNode(book)

        let ambient = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.72, alpha: 1)
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 820
        keyLight.color = UIColor(red: 1.0, green: 0.94, blue: 0.83, alpha: 1)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 9
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.22)
        keyLight.shadowMode = .deferred
        key.light = keyLight
        key.eulerAngles = SCNVector3(-0.55, -0.45, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 150
        fillLight.color = UIColor.white
        fill.position = SCNVector3(2.2, 1.4, 2.5)
        fill.light = fillLight
        scene.rootNode.addChildNode(fill)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 30
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.45)
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
        let size = CGSize(width: 720, height: 1020)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = isBack
                ? [UIColor(red: 0.30, green: 0.23, blue: 0.19, alpha: 1), UIColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1)]
                : [tint, tint.withAlphaComponent(0.76)]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let inset = CGRect(x: 43, y: 43, width: size.width - 86, height: size.height - 86)
            UIColor.white.withAlphaComponent(0.52).setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.stroke(inset)
            if !isBack {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineSpacing = 9
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Georgia", size: 51) ?? UIFont.systemFont(ofSize: 51, weight: .regular),
                    .foregroundColor: UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1),
                    .paragraphStyle: paragraph
                ]
                let imprintAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.76),
                    .kern: 4
                ]
                title.draw(in: CGRect(x: 78, y: 300, width: 564, height: 330), withAttributes: titleAttributes)
                "A BOOK TO KEEP".draw(in: CGRect(x: 78, y: 850, width: 564, height: 40), withAttributes: imprintAttributes)
            } else {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let copyAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Georgia", size: 24) ?? UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.68),
                    .paragraphStyle: paragraph
                ]
                "A story belongs on a shelf\nand in the hands of a reader."
                    .draw(in: CGRect(x: 85, y: 390, width: 550, height: 130), withAttributes: copyAttributes)
            }
        }
    }

    private func pageMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.91, green: 0.875, blue: 0.79, alpha: 1)
        material.roughness.contents = 0.94
        return material
    }

    private func coverMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = tint
        material.roughness.contents = 0.82
        return material
    }

    private func ruleMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.72, green: 0.67, blue: 0.58, alpha: 1)
        material.lightingModel = .constant
        return material
    }

    final class Coordinator: NSObject {
        weak var view: SCNView?
        var signature = ""

        @objc func tapBook(_ recognizer: UITapGestureRecognizer) {
            guard let view,
                  let book = view.scene?.rootNode.childNode(withName: "folio-book", recursively: true) else { return }
            let current = book.eulerAngles
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.42
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            book.eulerAngles = SCNVector3(current.x, current.y + 0.28, current.z)
            SCNTransaction.commit()
        }
    }
}
