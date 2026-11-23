import SwiftUI
import SceneKit

struct BookPreview3D: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let book: Book
    var onOpenReader: (Book) -> Void

    @State private var allow3DRotate = true
    @State private var coverUIImage: UIImage?
    @State private var detailTab = 0

    private var liveBook: Book {
        library.books.first(where: { $0.id == book.id }) ?? book
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.21, green: 0.15, blue: 0.10),
                    FolioPalette.bg
                ],
                center: .center,
                startRadius: 20,
                endRadius: 460
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(FolioPalette.cream)
                                .frame(width: 38, height: 38)
                                .background(FolioPalette.cardElevated, in: Circle())
                        }
                        Spacer()
                        Text("Book Preview")
                            .font(.system(size: 18, design: .serif))
                            .foregroundStyle(FolioPalette.cream)
                        Spacer()
                        Button { library.toggleFavorite(liveBook) } label: {
                            Image(systemName: liveBook.isFavorite ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(FolioPalette.gold)
                                .frame(width: 38, height: 38)
                                .background(FolioPalette.cardElevated, in: Circle())
                        }
                    }
                    .padding(.top, 10)

                    HardcoverStageView(
                        coverImage: coverUIImage ?? fallbackCover,
                        allowDrag: allow3DRotate
                    )
                    .frame(height: 300)

                    Button { allow3DRotate.toggle() } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .strokeBorder(FolioPalette.gold, lineWidth: 1.5)
                                    .frame(width: 42, height: 42)
                                Text("3D")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(FolioPalette.gold)
                            }
                            Text(allow3DRotate ? "Drag book to rotate in 3D" : "Tap to view in 3D")
                                .font(.caption2)
                                .foregroundStyle(FolioPalette.muted)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 4) {
                        Text(liveBook.title)
                            .font(.system(size: 26, design: .serif))
                            .foregroundStyle(FolioPalette.cream)
                            .multilineTextAlignment(.center)
                        Text(liveBook.author)
                            .font(.subheadline)
                            .foregroundStyle(FolioPalette.muted)
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundStyle(FolioPalette.gold)
                            Text(String(format: "%.1f", liveBook.rating ?? 4.8))
                                .fontWeight(.semibold)
                                .foregroundStyle(FolioPalette.cream)
                            Text("• \(liveBook.fileFormat.rawValue)")
                                .foregroundStyle(FolioPalette.muted)
                        }
                        .font(.caption)
                    }

                    Button {
                        library.markOpened(liveBook)
                        onOpenReader(liveBook)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(liveBook.progressPercent > 0 ? "Continue Reading" : "Open 3D Book")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FolioPalette.gold, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        library.toggleFavorite(liveBook)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: liveBook.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(FolioPalette.gold)
                            Text(liveBook.isFavorite ? "In Favorites" : "Add to Favorites")
                                .foregroundStyle(FolioPalette.cream)
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FolioPalette.border, lineWidth: 1))
                    }

                    HStack(spacing: 0) {
                        tabSegment("About", 0)
                        tabSegment("Chapters", 1)
                        tabSegment("Details", 2)
                    }

                    Group {
                        if detailTab == 0 {
                            Text(liveBook.synopsis ?? liveBook.readingNote ?? "Ready to read in Folio's interactive 3D book reader.")
                        } else if detailTab == 1 {
                            Text("Page \(liveBook.currentPage ?? 1) of \(liveBook.totalPages ?? 1)")
                        } else {
                            Text("Format: \(liveBook.fileFormat.rawValue) • Status: \(liveBook.status.rawValue)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(FolioPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
        .task {
            if let str = liveBook.coverURL,
               let url = URL(string: str),
               url.scheme == "https",
               let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                coverUIImage = img
            }
        }
    }

    private func tabSegment(_ title: String, _ idx: Int) -> some View {
        let active = detailTab == idx
        return Button { detailTab = idx } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(active ? .semibold : .regular))
                    .foregroundStyle(active ? FolioPalette.gold : FolioPalette.muted)
                Rectangle()
                    .fill(active ? FolioPalette.gold : FolioPalette.border)
                    .frame(height: active ? 2 : 1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var fallbackCover: UIImage {
        let size = CGSize(width: 800, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.16, green: 0.12, blue: 0.09, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            liveBook.title.draw(
                in: CGRect(x: 70, y: 420, width: 660, height: 340),
                withAttributes: [
                    .font: UIFont(name: "Georgia-Bold", size: 64) ?? UIFont.boldSystemFont(ofSize: 64),
                    .foregroundColor: UIColor(red: 0.90, green: 0.77, blue: 0.55, alpha: 1),
                    .paragraphStyle: style
                ]
            )
        }
    }
}

private struct HardcoverStageView: UIViewRepresentable {
    let coverImage: UIImage
    let allowDrag: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = allowDrag

        let scene = SCNScene()
        let box = SCNBox(width: 2.25, height: 3.35, length: 0.40, chamferRadius: 0.04)

        let front = SCNMaterial()
        front.diffuse.contents = coverImage
        let spine = SCNMaterial()
        spine.diffuse.contents = UIColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1)
        let pages = SCNMaterial()
        pages.diffuse.contents = UIColor(red: 0.89, green: 0.83, blue: 0.72, alpha: 1)

        box.materials = [front, pages, spine, spine, pages, pages]

        let node = SCNNode(geometry: box)
        node.name = "hardcover"
        node.eulerAngles = SCNVector3(-0.08, 0.42, 0.03)
        scene.rootNode.addChildNode(node)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 1100
        light.light?.color = UIColor(red: 1.0, green: 0.90, blue: 0.74, alpha: 1)
        light.position = SCNVector3(-2.4, 3.0, 5.5)
        scene.rootNode.addChildNode(light)

let cam = SCNNode()
cam.camera = SCNCamera()
cam.camera?.fieldOfView = 35
cam.position = SCNVector3(0, 0, 7.6)
scene.rootNode.addChildNode(cam)
view.scene = scene
return view
}
func updateUIView(_ view: SCNView, context: Context) {
view.allowsCameraControl = allowDrag
view.scene?.rootNode.childNode(withName: "hardcover", recursively: true)?
.geometry?.materials.first?.diffuse.contents = coverImage
}
}
