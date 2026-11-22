import SwiftUI
import PDFKit
import QuickLook
import UniformTypeIdentifiers

private let folioPaper = Color(red: 0.96, green: 0.94, blue: 0.89)
private let folioInk = Color(red: 0.18, green: 0.20, blue: 0.17)

struct ContentView: View {
    @AppStorage("folio.hasWelcomed") private var hasWelcomed = false

    var body: some View {
        if hasWelcomed {
            FolioTabs()
        } else {
            WelcomeView {
                withAnimation(.easeInOut(duration: 0.35)) { hasWelcomed = true }
            }
        }
    }
}

private struct FolioTabs: View {
    var body: some View {
        TabView {
            LibraryScreen()
                .tabItem { Label("My shelf", systemImage: "books.vertical") }
            CommunityView()
                .tabItem { Label("Reading room", systemImage: "text.bubble") }
            ProfileView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
        .tint(folioInk)
    }
}

private struct LibraryScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var showingAddBook = false
    @State private var selectedBook: Book?
    @State private var showingFirstBookTutorial = false
    @State private var openAddBookAfterTutorial = false
    @AppStorage("folio.firstBookTutorialSeen") private var firstBookTutorialSeen = false

    var body: some View {
        NavigationStack {
            ZStack {
                folioPaper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        FolioHeader(add: { showingAddBook = true }, tutorial: { showingFirstBookTutorial = true })
                        intro
                        shelfCounts
                        BookGrid(books: library.books) { selectedBook = $0 }
                        footer
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if !firstBookTutorialSeen {
                showingFirstBookTutorial = true
            }
        }
        .sheet(isPresented: $showingFirstBookTutorial, onDismiss: {
            firstBookTutorialSeen = true
            if openAddBookAfterTutorial {
                openAddBookAfterTutorial = false
                showingAddBook = true
            }
        }) {
            FirstBookTutorialView {
                openAddBookAfterTutorial = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddBook) {
            AddBookView()
                .environmentObject(library)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book)
                .environmentObject(library)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("YOUR LITTLE\nCORNER OF THE\nLITERARY WORLD.")
                .font(.system(size: 33, weight: .regular, design: .serif))
                .tracking(-1.1)
                .lineSpacing(-1)
                .foregroundStyle(folioInk)
            Text("Keep the stories you love, and the ones you're yet to find.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(folioInk.opacity(0.68))
        }
        .padding(.top, 15)
    }

    private var shelfCounts: some View {
        HStack(spacing: 8) {
            ForEach(ReadingStatus.allCases) { status in
                NavigationLink {
                    ShelfListView(status: status) { selectedBook = $0 }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(status.rawValue.uppercased())
                            .font(.system(size: 9, weight: .semibold)).tracking(1)
                        Text(String(library.books(for: status).count))
                            .font(.system(size: 25, design: .serif))
                    }
                    .foregroundStyle(folioInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(.white.opacity(0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("READ SLOWLY. KEEP THE GOOD ONES.")
                .font(.system(size: 9, weight: .medium)).tracking(1.6)
            Spacer()
            Image(systemName: "leaf")
        }
        .foregroundStyle(folioInk.opacity(0.42))
    }
}

private struct FolioHeader: View {
    let add: () -> Void
    let tutorial: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOLIO").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(3.5)
                Text("a life between the pages").font(.system(size: 12, design: .serif).italic()).foregroundStyle(folioInk.opacity(0.62))
            }
            Spacer()
            Button(action: tutorial) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(folioInk.opacity(0.7))
                    .frame(width: 38, height: 42)
            }
            .accessibilityLabel("How Folio works")
            Button {
                add()
                SoundEffects.softTap()
            } label: {
                Image(systemName: "plus").font(.system(size: 17, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(folioInk).foregroundStyle(folioPaper).clipShape(Circle())
            }
            .accessibilityLabel("Add a book")
        }
        .foregroundStyle(folioInk)
    }
}

private struct BookGrid: View {
    let books: [Book]
    let select: (Book) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("On your shelf").font(.system(size: 23, design: .serif))
                Spacer()
                Text("\(books.count) BOOKS").font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(folioInk.opacity(0.5))
            }
            if books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical").font(.system(size: 30, weight: .ultraLight))
                    Text("A little room for a new story.").font(.system(size: 15, design: .serif).italic())
                }
                .foregroundStyle(folioInk.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)], spacing: 25) {
                ForEach(books) { book in
                    Button {
                        select(book)
                        SoundEffects.pageTurn()
                    } label: {
                        BookSpine(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 23)
            .background {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Color(red: 0.89, green: 0.84, blue: 0.75), Color(red: 0.78, green: 0.70, blue: 0.59)], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(Color(red: 0.60, green: 0.48, blue: 0.36)).frame(height: 9)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.22)).frame(height: 1) }
                    Rectangle().fill(Color.black.opacity(0.10)).frame(height: 5).offset(y: -9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 5)
            }
            }
            Rectangle().fill(folioInk.opacity(0.65)).frame(height: 3)
            Rectangle().fill(folioInk.opacity(0.12)).frame(height: 2)
        }
        .foregroundStyle(folioInk)
    }
}

private struct BookSpine: View {
    let book: Book
    private let palette: [Color] = [
        Color(red: 0.43, green: 0.31, blue: 0.27), Color(red: 0.32, green: 0.40, blue: 0.35),
        Color(red: 0.69, green: 0.48, blue: 0.33), Color(red: 0.37, green: 0.39, blue: 0.51),
        Color(red: 0.62, green: 0.56, blue: 0.43), Color(red: 0.53, green: 0.34, blue: 0.36)
    ]
    private var spineArtwork: some View {
        VStack(spacing: 5) {
            Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
            Text(book.title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .tracking(0.7).multilineTextAlignment(.center).lineLimit(5)
                .minimumScaleFactor(0.7).foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 5)
            Spacer(minLength: 2)
            Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
            Text("✳").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette[book.colorIndex % palette.count].gradient)
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 2, y: 4)
                if let coverURL = book.coverURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            spineArtwork
                        default:
                            spineArtwork.overlay { ProgressView().tint(.white.opacity(0.7)) }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    spineArtwork
                }
            }
            .frame(height: 154)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(alignment: .leading) {
                LinearGradient(colors: [.black.opacity(0.24), .clear, .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 9)
            }
            .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.10)).frame(width: 2) }
            .rotation3DEffect(.degrees(-4), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
            Text(book.author).font(.system(size: 10, design: .serif)).foregroundStyle(folioInk.opacity(0.7)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ShelfListView: View {
    @EnvironmentObject private var library: LibraryStore
    let status: ReadingStatus
    let select: (Book) -> Void
    var body: some View {
        List(library.books(for: status)) { book in
            Button { select(book) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.system(size: 17, design: .serif)).foregroundStyle(folioInk)
                    Text(book.author).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .scrollContentBackground(.hidden)
        .background(folioPaper)
        .navigationTitle(status.rawValue)
    }
}

private struct BookDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentPageText = ""
    @State private var totalPagesText = ""
    @State private var readingNote = ""
    @State private var scanning = false
    @State private var importing = false
    @State private var reading = false
    @State private var message: String?
    @State private var readerURL: URL?
    @State private var timerStart: Date?
    @State private var elapsed: TimeInterval = 0
    let book: Book

    private var savedBook: Book { library.books.first(where: { $0.id == book.id }) ?? book }
    private var readyToRead: Bool { savedBook.ownedISBN != nil && savedBook.digitalFileName != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(book.title).font(.system(size: 25, design: .serif)).multilineTextAlignment(.center)
                Text(book.author.uppercased()).font(.system(size: 10, weight: .medium)).tracking(1.4).foregroundStyle(.secondary)
                BookPreview3D(title: book.title, tint: UIColor(red: 0.43, green: 0.31, blue: 0.27, alpha: 1), coverURL: book.coverURL).frame(height: 250)
                Text("Drag to turn your book around").font(.system(size: 12, design: .serif).italic()).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR READING COPY").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(folioInk.opacity(0.5))
                    if savedBook.ownedISBN != nil {
                        Label("Physical edition verified", systemImage: "checkmark.seal.fill").font(.system(size: 12, design: .serif)).foregroundStyle(.green)
                    } else {
                        Text("Scan the barcode on your physical copy to verify the edition.")
                            .font(.system(size: 12, design: .serif)).foregroundStyle(.secondary)
                        Button { scanning = true } label: {
                            Label("Scan my book's barcode", systemImage: "barcode.viewfinder")
                                .frame(maxWidth: .infinity).padding(11).background(folioInk).foregroundStyle(folioPaper).clipShape(Capsule())
                        }
                    }
                    if let name = savedBook.digitalFileName {
                        Label(name, systemImage: "doc.text").font(.system(size: 11, design: .serif)).lineLimit(1)
                    }
                    Button { importing = true } label: {
                        Label(savedBook.digitalFileName == nil ? "Import my EPUB or PDF" : "Replace reading copy", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity).padding(11).background(.white.opacity(0.7)).foregroundStyle(folioInk).clipShape(Capsule())
                    }
                    Button {
                        openReader()
                    } label: {
                        Label("Open reading room", systemImage: "book.pages")
                            .frame(maxWidth: .infinity).padding(12).background(readyToRead ? folioInk : folioInk.opacity(0.3)).foregroundStyle(folioPaper).clipShape(Capsule())
                    }
                    .disabled(!readyToRead)
                    if let message { Text(message).font(.system(size: 11, design: .serif)).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("READING SESSION").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(folioInk.opacity(0.5))
                    HStack {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            let seconds = Int(elapsed + (timerStart.map { Date().timeIntervalSince($0) } ?? 0))
                            Text(String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60))
                                .font(.system(size: 26, design: .serif).monospacedDigit())
                        }
                        Spacer()
                        Button(timerStart == nil ? "Start" : "Pause") {
                            if let start = timerStart { elapsed += Date().timeIntervalSince(start); timerStart = nil }
                            else { timerStart = Date() }
                            SoundEffects.softTap()
                        }.font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(14).background(.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 10) {
                    Text("A LITTLE READING JOURNAL").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(folioInk.opacity(0.5))
                    HStack(spacing: 10) {
                        TextField("Current page", text: $currentPageText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        Text("of").foregroundStyle(.secondary)
                        TextField("Total pages", text: $totalPagesText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    }
                    if let total = Int(totalPagesText), total > 0, let current = Int(currentPageText) {
                        ProgressView(value: min(Double(max(current, 0)), Double(total)), total: Double(total)).tint(folioInk)
                    }
                    TextField("A thought, a favourite line, a note to yourself…", text: $readingNote, axis: .vertical)
                        .lineLimit(2...4).font(.system(size: 13, design: .serif)).padding(10).background(.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 5))
                    Button {
                        library.updateReadingDetails(book, currentPage: Int(currentPageText), totalPages: Int(totalPagesText), note: readingNote)
                        SoundEffects.softTap()
                    } label: {
                        Text("Save my reading notes").font(.system(size: 12, weight: .medium)).foregroundStyle(folioPaper)
                            .frame(maxWidth: .infinity).padding(.vertical, 11).background(folioInk).clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Reading status", selection: Binding(get: { savedBook.status }, set: { library.update(book, status: $0) })) {
                    ForEach(ReadingStatus.allCases) { status in Text(status.rawValue).tag(status) }
                }.pickerStyle(.segmented)
                Button(role: .destructive) { library.remove(book); dismiss() } label: {
                    Label("Remove from my shelf", systemImage: "trash").font(.system(size: 12, weight: .medium))
                }
            }
            .padding(22)
        }
        .background(folioPaper.ignoresSafeArea())
        .onAppear {
            currentPageText = book.currentPage.map(String.init) ?? ""
            totalPagesText = book.totalPages.map(String.init) ?? ""
            readingNote = book.readingNote ?? ""
        }
        .sheet(isPresented: $scanning) {
            NavigationStack {
                ISBNScannerView(onScan: { code in
                    scanning = false
                    Task { await verifyBarcode(code) }
                }, onCancel: { scanning = false })
                .ignoresSafeArea()
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { scanning = false } } }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, UTType(filenameExtension: "epub") ?? .data], allowsMultipleSelection: false) { result in
            importCopy(result)
        }
        .sheet(isPresented: $reading) {
            if let readerURL { FolioReadingCopyView(url: readerURL) }
        }
    }

    private func verifyBarcode(_ code: String) async {
        let clean = code.filter(\.isNumber)
        if let isbn = savedBook.isbn, isbn == clean {
            library.verifyOwnership(book, scannedISBN: clean)
            return
        }
        do {
            if let match = try await BookLookupService().lookup(isbn: clean),
               match.title.localizedCaseInsensitiveCompare(book.title) == .orderedSame {
                library.verifyOwnership(book, scannedISBN: clean)
            } else {
                message = "That barcode doesn't match this title. Try the ISBN on your copy."
            }
        } catch {
            message = "Couldn't verify the barcode. Check your connection and try again."
        }
    }

    private func importCopy(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { return }
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let ext = source.pathExtension.lowercased()
            guard ext == "pdf" || ext == "epub" else { message = "Choose an EPUB or PDF file."; return }
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = folder.appendingPathComponent(book.id.uuidString + "." + ext)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.copyItem(at: source, to: destination)
            library.attachDigitalCopy(book, fileName: destination.lastPathComponent)
            message = "Your reading copy is saved on this iPhone."
        } catch { message = "Couldn't import that file. Please try again." }
    }

    private func openReader() {
        guard let name = savedBook.digitalFileName else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { message = "That file is missing. Please import it again."; return }
        readerURL = url
        reading = true
    }
}

private struct FolioReadingCopyView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    var body: some View {
        NavigationStack {
            Group {
                if url.pathExtension.lowercased() == "pdf" {
                    FolioPDFView(url: url)
                } else {
                    FolioEPUBPreview(url: url)
                }
            }
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct FolioPDFView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}

private struct FolioEPUBPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

private struct FirstBookTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    let onStartAdding: () -> Void
    @State private var page = 0

    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)

    private let steps: [(symbol: String, eyebrow: String, title: String, detail: String)] = [
        ("books.vertical.fill", "WELCOME TO YOUR SHELF", "A home for every story.", "Build a personal library that feels like your own little bookshop. Your collection stays on your iPhone."),
        ("barcode.viewfinder", "FIND YOUR NEXT READ", "Search, scan, or simply type.", "Add a book by ISBN barcode or catalogue search. If a book is hard to find, enter its title and author yourself."),
        ("bookmark.fill", "MAKE IT YOUR EDITION", "Give every book a place.", "Sort books into To Read, Reading, and Read. Open a book to customise its edition, record pages, and keep private reading notes."),
        ("book.pages", "READ WHAT YOU OWN", "Bring your own reading copy.", "For books you own, verify the printed ISBN and import your own EPUB or PDF file to open it in Folio. A shelf entry alone does not include a digital book."),
        ("hourglass", "MAKE TIME FOR STORIES", "Read at your own pace.", "Use the reading timer, keep track of progress, and visit the Reading Room to share genuine notes with other readers.")
    ]

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("A NOTE FROM FOLIO")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(ink.opacity(0.48))
                    Spacer()
                    Button("Skip") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(ink.opacity(0.65))
                }
                .padding(.top, 22)

                Spacer()
                Image(systemName: steps[page].symbol)
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(ink)
                    .frame(height: 90)
                    .padding(.bottom, 34)

                Text(steps[page].eyebrow)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(ink.opacity(0.48))
                Text(steps[page].title)
                    .font(.system(size: 34, design: .serif))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text(steps[page].detail)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ink.opacity(0.7))
                    .frame(maxWidth: 300)
                    .padding(.top, 14)

                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(ink.opacity(index == page ? 0.85 : 0.18))
                            .frame(width: index == page ? 25 : 7, height: 5)
                    }
                }
                .padding(.bottom, 25)

                Button {
                    if page < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                    } else {
                        onStartAdding()
                        dismiss()
                    }
                    SoundEffects.softTap()
                } label: {
                    HStack {
                        Text(page == steps.count - 1 ? "Start my collection" : "Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ink)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 26)
        }
    }
}
