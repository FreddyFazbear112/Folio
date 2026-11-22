import SwiftUI
import WebKit
import ZIPFoundation
import FoundationXML

private struct FolioEPUBChapter: Identifiable {
    let id: String
    let title: String
    let url: URL
}
private struct FolioEPUBContents {
    let root: URL
    let title: String
    let chapters: [FolioEPUBChapter]
}
private final class FolioEPUBParser: NSObject, XMLParserDelegate {
    var rootfile: String?
    var title = ""
    var manifest: [String:String] = [:]
    var spine: [String] = []
    private var inTitle = false
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String:String] = [:]) {
        if name == "rootfile" { rootfile = attributes["full-path"] }
        if name == "item", let id = attributes["id"], let href = attributes["href"], attributes["media-type"]?.contains("html") == true { manifest[id] = href }
        if name == "itemref", let id = attributes["idref"] { spine.append(id) }
        if name == "dc:title" || name == "title" { inTitle = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inTitle { title += string } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) { if name == "dc:title" || name == "title" { inTitle = false } }
}
private enum FolioEPUBArchive {
    static func open(_ source: URL) throws -> FolioEPUBContents {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Folio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard let archive = Archive(url: source, accessMode: .read) else { throw URLError(.cannotDecodeContentData) }
        for entry in archive {
            let target = root.appendingPathComponent(entry.path).standardizedFileURL
            guard target.path.hasPrefix(root.standardizedFileURL.path + "/") else { continue }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: target)
        }
        let container = FolioEPUBParser()
        guard let cp = XMLParser(contentsOf: root.appendingPathComponent("META-INF/container.xml")) else { throw URLError(.cannotParseResponse) }
        cp.delegate = container
        guard cp.parse(), let opf = container.rootfile else { throw URLError(.cannotParseResponse) }
        let opfURL = root.appendingPathComponent(opf)
        let book = FolioEPUBParser()
        guard let bp = XMLParser(contentsOf: opfURL) else { throw URLError(.cannotParseResponse) }
        bp.delegate = book
        guard bp.parse() else { throw URLError(.cannotParseResponse) }
        let base = opfURL.deletingLastPathComponent()
        let chapters = book.spine.compactMap { id -> FolioEPUBChapter? in
            guard let href = book.manifest[id] else { return nil }
            let file = base.appendingPathComponent(href.removingPercentEncoding ?? href).standardizedFileURL
            guard file.path.hasPrefix(root.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: file.path) else { return nil }
            return FolioEPUBChapter(id: id, title: file.deletingPathExtension().lastPathComponent, url: file)
        }
        guard !chapters.isEmpty else { throw URLError(.cannotDecodeContentData) }
        let title = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return FolioEPUBContents(root: root, title: title.isEmpty ? source.deletingPathExtension().lastPathComponent : title, chapters: chapters)
    }
}

struct FolioEPUBReader: View {
    let url: URL
    let sepia: Bool
    let initialChapter: Int
    let onProgress: (Int, Int) -> Void
    @State private var contents: FolioEPUBContents?
    @State private var index = 0
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            if let contents, contents.chapters.indices.contains(index) {
                HStack {
                    Button { turn(-1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                    Spacer()
                    VStack(spacing: 3) {
                        Text(contents.title).font(.system(size: 12, weight: .semibold, design: .serif)).lineLimit(1)
                        Text("CHAPTER \(index + 1) OF \(contents.chapters.count)").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                    }
                    Spacer()
                    Button { turn(1) } label: { Image(systemName: "chevron.right") }.disabled(index >= contents.chapters.count - 1)
                }
                .foregroundStyle(sepia ? Color(red: 0.22, green: 0.21, blue: 0.18) : .white)
                .padding(.horizontal, 20).padding(.vertical, 9)
                FolioEPUBWebPage(chapter: contents.chapters[index], root: contents.root, sepia: sepia)
                HStack {
                    Text(contents.chapters[index].title).lineLimit(1)
                    Spacer()
                    Text("\(Int(Double(index + 1) / Double(contents.chapters.count) * 100))%")
                }
                .font(.system(size: 9, design: .serif)).foregroundStyle(sepia ? .secondary : .white.opacity(0.65))
                .padding(.horizontal, 18).padding(.vertical, 8)
            } else if loading {
                ProgressView("Opening your book…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed").font(.system(size: 28, weight: .light))
                    Text("This EPUB couldn't be opened").font(.system(size: 20, design: .serif))
                    Text(error ?? "The file may be damaged or use an unsupported layout.").font(.system(size: 12, design: .serif)).multilineTextAlignment(.center)
                    Button("Try again") { load() }
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(sepia ? Color(red: 0.94, green: 0.90, blue: 0.82) : Color(red: 0.12, green: 0.13, blue: 0.13))
        .task { load() }
    }
    private func turn(_ delta: Int) {
        index = min(max(index + delta, 0), (contents?.chapters.count ?? 1) - 1)
        SoundEffects.pageTurn()
        onProgress(index + 1, contents?.chapters.count ?? 1)
    }
    private func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try FolioEPUBArchive.open(url)
                DispatchQueue.main.async { index = min(max(initialChapter, 0), result.chapters.count - 1); contents = result; loading = false; onProgress(index + 1, result.chapters.count) }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription; loading = false }
            }
        }
    }
}
private struct FolioEPUBWebPage: UIViewRepresentable {
    let chapter: FolioEPUBChapter
    let root: URL
    let sepia: Bool
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        let paper = sepia ? "#f0e7d5" : "#202321"
        let ink = sepia ? "#302e29" : "#eee9df"
        let css = "html,body{background:\(paper)!important;color:\(ink)!important;font-family:Georgia,serif!important;font-size:18px!important;line-height:1.85!important;}body{padding:22px 18px 36px!important;max-width:46rem!important;margin:0 auto!important;}img,svg{max-width:100%!important;height:auto!important;}a{color:\(ink)!important;}"
        let escapedCSS = css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let script = "var folioStyle=document.createElement('style');folioStyle.innerHTML='\(escapedCSS)';document.head.appendChild(folioStyle);"
        view.configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        view.isOpaque = false
        view.backgroundColor = sepia ? UIColor(red: 0.94, green: 0.90, blue: 0.82, alpha: 1) : UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor
        view.scrollView.contentInset = UIEdgeInsets(top: 20, left: 16, bottom: 24, right: 16)
        view.loadFileURL(chapter.url, allowingReadAccessTo: root)
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url != chapter.url { view.loadFileURL(chapter.url, allowingReadAccessTo: root) }
    }
}
