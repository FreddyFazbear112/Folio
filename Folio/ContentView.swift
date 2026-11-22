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
            FolioLibraryHome()
                .tabItem { Label("My shelf", systemImage: "books.vertical") }
            CommunityView()
                .tabItem { Label("Reading room", systemImage: "text.bubble") }
            ProfileView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
        .tint(folioInk)
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
    @State private var frontCoverURLText = ""
    @State private var backCoverURLText = ""
    @State private var spineColorHex = "765447"
    @State private var editionMessage: String?
    @State private var scanning = false
    @State private var importing = false
    @State private var reading = false
    @State private var message: String?
    @State private var readerURL: URL?
    @State private var timerStart: Date?
    @State private var elapsed: TimeInterval = 0
    let book: Book

    private var savedBook: Book { library.books.first(where: { $0.id == book.id }) ?? book }
    private var readyToRead: Bool { savedBook.digitalFileName != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 7) {
                    Text(savedBook.title)
                        .font(.system(size: 29, weight: .regular, design: .serif))
                        .tracking(-0.7)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                    Text(savedBook.author.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2.2)
                        .foregroundStyle(folioInk.opacity(0.48))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                VStack(spacing: 8) {
                    BookPreview3D(title: savedBook.title, tint: spineTint, coverURL: savedBook.coverURL, backCoverURL: savedBook.backCoverURL)
                        .frame(height: 225)
                    Text("TURN THE BOOK TO EXPLORE IT")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.7)
                        .foregroundStyle(folioInk.opacity(0.42))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.30))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("EDITION STUDIO")
                    Text("Make this copy feel like yours. Add artwork hosted online and choose a spine finish.")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(folioInk.opacity(0.62))
                    DisclosureGroup("Customize cover and spine") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FRONT COVER IMAGE URL").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(folioInk.opacity(0.5))
                            TextField("https://…", text: $frontCoverURLText).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            Text("BACK COVER IMAGE URL").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(folioInk.opacity(0.5))
                            TextField("https://…", text: $backCoverURLText).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            Text("SPINE FINISH").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(folioInk.opacity(0.5))
                            HStack(spacing: 12) {
                                ForEach(["765447", "34463D", "293C52", "8A713F", "5B3940", "383532"], id: \.self) { hex in
                                    Button { spineColorHex = hex } label: {
                                        Circle().fill(Color(red: Double(Int(hex.prefix(2), radix: 16) ?? 0) / 255, green: Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255, blue: Double(Int(hex.suffix(2), radix: 16) ?? 0) / 255))
                                            .frame(width: 27, height: 27)
                                            .overlay(Circle().stroke(spineColorHex == hex ? folioInk : .clear, lineWidth: 2).padding(-4))
                                    }.buttonStyle(.plain)
                                }
                            }
                            Button("Save edition design") {
                                let front = URL(string: frontCoverURLText.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme == "https" ? frontCoverURLText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                                let back = URL(string: backCoverURLText.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme == "https" ? backCoverURLText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                                library.updateEdition(book, coverURL: front, spineColorHex: spineColorHex, backCoverURL: back)
                                editionMessage = "Your edition design has been saved."
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(folioPaper).padding(.horizontal, 15).padding(.vertical, 11)
                            .background(folioInk, in: Capsule())
                            if let editionMessage { Text(editionMessage).font(.system(size: 10, design: .serif)).foregroundStyle(.secondary) }
                        }
                        .padding(.top, 10)
                    }
                    .font(.system(size: 13, weight: .medium, design: .serif))
                }
                .padding(16)
                .background(Color.white.opacity(0.48))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionLabel("YOUR READING COPY")
                        Spacer()
                        if savedBook.digitalFileName != nil {
                            Label("ON THIS DEVICE", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .semibold)).tracking(0.8)
                                .foregroundStyle(Color(red: 0.30, green: 0.43, blue: 0.32))
                        }
                    }
                    if let name = savedBook.digitalFileName {
                        Label(name, systemImage: "book.pages")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(folioInk.opacity(0.62)).lineLimit(1)
                        actionRow("Start reading", symbol: "book.pages", prominent: true) { openReader() }
                    } else {
                        Text("A free digital edition will appear here when the catalogue has one available.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(folioInk.opacity(0.62))
                    }
                    if savedBook.ownedISBN == nil {
                        DisclosureGroup {
                            Text("Scan the barcode on your printed copy to record its edition. This is optional and isn't required to read free digital books.")
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(folioInk.opacity(0.58))
                            actionRow("Verify physical edition", symbol: "barcode.viewfinder") { scanning = true }
                        } label: {
                            Text("I own a printed copy")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(folioInk.opacity(0.72))
                        }
                    } else {
                        Label("Printed edition verified", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(Color(red: 0.30, green: 0.43, blue: 0.32))
                    }
                    if savedBook.digitalFileName == nil {
                        actionRow("Import a file I already have", symbol: "square.and.arrow.down") { importing = true }
                    }
                    if let message { Text(message).font(.system(size: 12, design: .serif)).foregroundStyle(.secondary) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionLabel("A MOMENT FOR READING")
                        Spacer()
                        Circle().fill(timerStart == nil ? folioInk.opacity(0.2) : Color(red: 0.35, green: 0.49, blue: 0.36))
                            .frame(width: 6, height: 6)
                        Text(timerStart == nil ? "PAUSED" : "IN SESSION")
                            .font(.system(size: 8, weight: .semibold)).tracking(1.2)
                            .foregroundStyle(folioInk.opacity(0.48))
                    }
                    HStack(alignment: .center) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = max(0, Int((timerStart.map { context.date.timeIntervalSince($0) } ?? elapsed)))
                            Text(String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60))
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(folioInk)
                        }
                        Spacer()
                        Button {
                            if let started = timerStart {
                                elapsed += Date().timeIntervalSince(started)
                                timerStart = nil
                                Task {
                                    await ReadingActivityManager.shared.update(
                                        elapsed: Int(elapsed), paused: true,
                                        title: savedBook.title, author: savedBook.author
                                    )
                                }
                            } else {
                                timerStart = Date()
                                if elapsed == 0 {
                                    ReadingActivityManager.shared.start(
                                        bookID: savedBook.id.uuidString,
                                        title: savedBook.title, author: savedBook.author
                                    )
                                } else {
                                    Task {
                                        await ReadingActivityManager.shared.update(
                                            elapsed: Int(elapsed), paused: false,
                                            title: savedBook.title, author: savedBook.author
                                        )
                                    }
                                }
                            }
                            persistTimerState()
                            SoundEffects.softTap()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: timerStart == nil ? "play.fill" : "pause.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(timerStart == nil ? (elapsed == 0 ? "Begin" : "Resume") : "Pause")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(folioPaper)
                            .padding(.horizontal, 17).padding(.vertical, 12)
                            .background(folioInk)
                            .clipShape(Capsule())
                        }
                    }
                    if elapsed > 0 || timerStart != nil {
                        Button("End session") {
                            if let started = timerStart {
                                elapsed += Date().timeIntervalSince(started)
                                timerStart = nil
                            }
                            Task {
                                await ReadingActivityManager.shared.end(
                                    elapsed: Int(elapsed), title: savedBook.title, author: savedBook.author
                                )
                            }
                            message = "Reading session: " + String(format: "%d min", Int(elapsed / 60))
                            UserDefaults.standard.removeObject(forKey: timerElapsedKey)
                            UserDefaults.standard.removeObject(forKey: timerStartedKey)
                            elapsed = 0
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(folioInk.opacity(0.56))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.56))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("READING JOURNAL")
                    HStack(spacing: 10) {
                        TextField("Page", text: $currentPageText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        Text("of").font(.system(size: 13, design: .serif)).foregroundStyle(.secondary)
                        TextField("Total", text: $totalPagesText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    }
                    if let total = Int(totalPagesText), total > 0, let current = Int(currentPageText) {
                        ProgressView(value: min(Double(max(current, 0)), Double(total)), total: Double(total)).tint(folioInk)
                    }
                    TextField("A thought to remember…", text: $readingNote, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 14, design: .serif))
                        .padding(12)
                        .background(Color.white.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Button {
                        let current = Int(currentPageText)
                        let total = Int(totalPagesText)
                        if let current, current < 1 {
                            message = "Page number must be at least 1."
                        } else if let current, let total, current > total {
                            message = "Current page can't be greater than the total pages."
                        } else if let total, total < 1 {
                            message = "Total pages must be at least 1."
                        } else {
                            library.updateReadingDetails(book, currentPage: current, totalPages: total, note: readingNote)
                            message = "Your reading note has been saved."
                            SoundEffects.softTap()
                        }
                    } label: {
                        Text("Save journal entry")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(folioInk)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("ON YOUR SHELF")
                    Picker("Reading status", selection: Binding(get: { savedBook.status }, set: { library.update(book, status: $0) })) {
                        ForEach(ReadingStatus.allCases) { status in Text(status.rawValue).tag(status) }
                    }.pickerStyle(.segmented)
                    Button(role: .destructive) { library.remove(book); dismiss() } label: {
                        Label("Remove from shelf", systemImage: "trash").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.top, 5)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .background(folioPaper.ignoresSafeArea())
        .onAppear {
            currentPageText = book.currentPage.map(String.init) ?? ""
            totalPagesText = book.totalPages.map(String.init) ?? ""
            readingNote = book.readingNote ?? ""
            frontCoverURLText = book.coverURL ?? ""
            backCoverURLText = book.backCoverURL ?? ""
            spineColorHex = book.spineColorHex ?? "765447"
            elapsed = UserDefaults.standard.double(forKey: timerElapsedKey)
            if let started = UserDefaults.standard.object(forKey: timerStartedKey) as? Date {
                timerStart = started
            }
        }
        .onDisappear { persistTimerState() }
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
        .fullScreenCover(isPresented: $reading) {
            if let readerURL {
                FolioReadingCopyView(url: readerURL) { page, total in
                    currentPageText = String(page)
                    totalPagesText = String(total)
                    library.updateReadingDetails(book, currentPage: page, totalPages: total, note: readingNote)
                }
            }
        }
    }

    private var spineTint: UIColor {
        let hex = savedBook.spineColorHex ?? "765447"
        let value = UInt64(hex, radix: 16) ?? 0x765447
        return UIColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }

    private var timerElapsedKey: String { "folio.timer.elapsed.\(book.id.uuidString)" }
    private var timerStartedKey: String { "folio.timer.started.\(book.id.uuidString)" }

    private func persistTimerState() {
        UserDefaults.standard.set(elapsed, forKey: timerElapsedKey)
        if let timerStart {
            UserDefaults.standard.set(timerStart, forKey: timerStartedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: timerStartedKey)
        }
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(folioInk.opacity(0.48))
    }

    private func actionRow(_ title: String, symbol: String, prominent: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            SoundEffects.softTap()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                Text(title).font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .medium)).opacity(0.55)
            }
            .foregroundStyle(prominent ? folioPaper : folioInk)
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(prominent ? folioInk.opacity(disabled ? 0.28 : 1) : Color.white.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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
    var onProgress: (Int, Int) -> Void
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var sepia = true
    @State private var focusMode = false

    var body: some View {
        ZStack {
            (sepia ? Color(red: 0.91, green: 0.87, blue: 0.78) : Color(red: 0.12, green: 0.13, blue: 0.13))
                .ignoresSafeArea()
            VStack(spacing: 0) {
                if !focusMode {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.55), in: Circle())
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("FOLIO READER")
                                .font(.system(size: 8, weight: .bold)).tracking(2)
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.system(size: 12, design: .serif)).lineLimit(1)
                        }
                        Spacer()
                        Button { withAnimation(.easeInOut(duration: 0.2)) { sepia.toggle() } } label: {
                            Image(systemName: sepia ? "moon" : "sun.max")
                                .font(.system(size: 14))
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.55), in: Circle())
                        }
                    }
                    .foregroundStyle(sepia ? folioInk : Color.white)
                    .padding(.horizontal, 17)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
                if url.pathExtension.lowercased() == "pdf" {
                    FolioPDFView(url: url, currentPage: $currentPage, totalPages: $totalPages, sepia: sepia)
                        .ignoresSafeArea(edges: focusMode ? .all : [])
                } else {
                    FolioEPUBPreview(url: url)
                }
                if url.pathExtension.lowercased() == "pdf" && !focusMode {
                    VStack(spacing: 10) {
                        HStack(spacing: 22) {
                            Button {
                                currentPage = max(1, currentPage - 1)
                                SoundEffects.pageTurn()
                            } label: { Image(systemName: "chevron.left") }
                            Text(totalPages > 0 ? "PAGE \(currentPage) OF \(totalPages)" : "OPENING BOOK")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.1)
                            Button {
                                currentPage = min(max(totalPages, 1), currentPage + 1)
                                SoundEffects.pageTurn()
                            } label: { Image(systemName: "chevron.right") }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(sepia ? folioInk : Color.white)
                        if totalPages > 0 {
                            ProgressView(value: Double(currentPage), total: Double(totalPages))
                                .tint(sepia ? folioInk : Color.white)
                        }
                        HStack {
                            Text("A LITTLE TIME FOR A STORY")
                            Spacer()
                            Button("Focus") { withAnimation(.easeInOut(duration: 0.2)) { focusMode = true } }
                        }
                        .font(.system(size: 8, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(sepia ? folioInk.opacity(0.55) : Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 13)
                    .padding(.bottom, 12)
                } else if focusMode {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { focusMode = false }
                    } label: {
                        Label("Show reading controls", systemImage: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 15).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .foregroundStyle(sepia ? folioInk : .white)
                    .padding(.bottom, 12)
                }
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: currentPage) { _, page in
            guard totalPages > 0 else { return }
            onProgress(page, totalPages)
        }
    }
}

private struct FolioPDFView: UIViewRepresentable {
    let url: URL
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    let sepia: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.pageShadowsEnabled = true
        view.usePageViewController(true, withViewOptions: nil)
        view.backgroundColor = sepia
            ? UIColor(red: 0.91, green: 0.87, blue: 0.78, alpha: 1)
            : UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1)
        view.document = PDFDocument(url: url)
        context.coordinator.pdfView = view
        context.coordinator.observePageChanges()
        totalPages = view.document?.pageCount ?? 0
        currentPage = 1
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        view.backgroundColor = sepia
            ? UIColor(red: 0.91, green: 0.87, blue: 0.78, alpha: 1)
            : UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1)
        guard let document = view.document, document.pageCount > 0,
              let firstPage = document.page(at: 0) else { return }
        let target = min(max(currentPage - 1, 0), document.pageCount - 1)
        let visiblePage = view.currentPage ?? firstPage
        if document.index(for: visiblePage) != target, let page = document.page(at: target) {
            view.go(to: page)
        }
    }

    final class Coordinator: NSObject {
        var parent: FolioPDFView
        weak var pdfView: PDFView?
        private var lastPageIndex: Int?
        init(_ parent: FolioPDFView) { self.parent = parent }

        func observePageChanges() {
            NotificationCenter.default.addObserver(self, selector: #selector(pageChanged),
                name: .PDFViewPageChanged, object: pdfView)
        }

        @objc private func pageChanged() {
            guard let view = pdfView, let document = view.document, let page = view.currentPage else { return }
            let index = document.index(for: page) + 1
            if let lastPageIndex, lastPageIndex != index { SoundEffects.pageTurn() }
            lastPageIndex = index
            DispatchQueue.main.async {
                self.parent.currentPage = index
                self.parent.totalPages = document.pageCount
            }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
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
        ("bookmark.fill", "MAKE IT YOUR EDITION", "Give every book a place.", "Sort your library into To Read, Reading, and Read. Keep page progress and a private note for every story."),
        ("book.pages", "FIND IT. FOLIO FINDS THE FILE.", "Open a book, not a file picker.", "Search Folio's catalogue. Free public-domain EPUBs and PDFs can be downloaded straight to your shelf. Other editions are shown when no free digital copy is available."),
        ("hourglass", "MAKE TIME FOR STORIES", "Read at your own pace.", "Use the reading timer, keep track of progress, and visit the Reading Room when community features are configured.")
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


// MARK: - Folio editorial home
// A rebuilt library surface: reading-first hierarchy, generous editorial typography,
// compact status navigation and a tactile, horizontally browsable book collection.
private struct FolioLibraryHome: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedBook: Book?
    @State private var showingAddBook = false
    @State private var showingTour = false
    @State private var openAddAfterTour = false
    @AppStorage("folio.productTourSeen.v2") private var tourSeen = false

    private let paper = Color(red: 0.955, green: 0.936, blue: 0.888)
    private let ink = Color(red: 0.17, green: 0.19, blue: 0.16)
    private let muted = Color(red: 0.48, green: 0.45, blue: 0.39)
    private let walnut = Color(red: 0.39, green: 0.28, blue: 0.22)

    private var currentlyReading: Book? { library.books.first(where: { $0.status == .reading }) }
    private var recentBooks: [Book] { Array(library.books.prefix(12)) }

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 29) {
                        masthead
                        greeting
                        if let book = currentlyReading {
                            continueReading(book)
                        } else {
                            readingInvitation
                        }
                        collectionSection
                        statusOverview
                        closingNote
                    }
                    .padding(.horizontal, 23)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(ink)
        .sheet(isPresented: $showingAddBook) {
            AddBookView()
                .environmentObject(library)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book)
                .environmentObject(library)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTour, onDismiss: {
            if openAddAfterTour {
                openAddAfterTour = false
                showingAddBook = true
            }
        }) {
            FirstBookTutorialView {
                openAddAfterTour = true
                showingTour = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !tourSeen { showingTour = true; tourSeen = true }
        }
    }

    private var masthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FOLIO")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(4.2)
                Text("YOUR PRIVATE BOOKSHOP")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(muted)
            }
            Spacer()
            Button { showingTour = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 37, height: 37)
                    .background(.white.opacity(0.58), in: Circle())
                    .overlay(Circle().stroke(ink.opacity(0.08), lineWidth: 1))
            }
            .accessibilityLabel("How Folio works")
            Button {
                showingAddBook = true
                SoundEffects.softTap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(paper)
                    .frame(width: 40, height: 40)
                    .background(ink, in: Circle())
                    .shadow(color: ink.opacity(0.18), radius: 8, y: 4)
            }
            .accessibilityLabel("Add a book")
        }
        .foregroundStyle(ink)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Capsule().fill(walnut).frame(width: 22, height: 2)
                Text("A PLACE TO RETURN TO")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(muted)
            }
            Text("Make room\nfor a good story.")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .tracking(-1.5)
                .lineSpacing(-5)
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("A considered home for everything you read.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(muted)
        }
        .padding(.top, 7)
    }

    private func continueReading(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionEyebrow("PICK UP WHERE YOU LEFT OFF", trailing: "01")
            Button {
                selectedBook = book
                SoundEffects.pageTurn()
            } label: {
                HStack(spacing: 17) {
                    homeCover(book, width: 94, height: 137)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENTLY READING")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(muted)
                        Text(book.title)
                            .font(.system(size: 22, design: .serif))
                            .tracking(-0.45)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .foregroundStyle(ink)
                        Text(book.author)
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(muted)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        HStack(spacing: 7) {
                            Text("OPEN BOOK")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.3)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(walnut)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 137, alignment: .topLeading)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(muted)
                }
                .padding(15)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(ink.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var readingInvitation: some View {
        Button { showingAddBook = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(walnut.gradient)
                    Image(systemName: "book.closed")
                        .font(.system(size: 29, weight: .ultraLight))
                        .foregroundStyle(paper.opacity(0.9))
                }
                .frame(width: 76, height: 94)
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR NEXT CHAPTER")
                        .font(.system(size: 8, weight: .bold)).tracking(1.6).foregroundStyle(muted)
                    Text("Every reading life starts somewhere.")
                        .font(.system(size: 19, design: .serif)).foregroundStyle(ink)
                        .multilineTextAlignment(.leading)
                    Text("FIND YOUR FIRST BOOK  ↗")
                        .font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(walnut)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(ink.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("On your shelves")
                    .font(.system(size: 27, design: .serif))
                    .tracking(-0.7)
                    .foregroundStyle(ink)
                Spacer()
                Text(String(format: "%02d BOOKS", library.books.count))
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(muted)
            }
            if recentBooks.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 25, weight: .ultraLight))
                        .foregroundStyle(walnut.opacity(0.75))
                    Text("A shelf is built one story at a time.")
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundStyle(ink.opacity(0.8))
                    Text("Your collection will live here.")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 7))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 15) {
                        ForEach(recentBooks) { book in
                            Button {
                                selectedBook = book
                                SoundEffects.pageTurn()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    homeCover(book, width: 112, height: 164)
                                    Text(book.title)
                                        .font(.system(size: 12, weight: .medium, design: .serif))
                                        .foregroundStyle(ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 112, alignment: .leading)
                                    Text(book.status.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Button { showingAddBook = true } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundStyle(walnut)
                                    .frame(width: 112, height: 164)
                                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(walnut.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                                Text("ADD A BOOK")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(1.1)
                                    .foregroundStyle(muted)
                            }
                        }
                        .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                        .padding(.trailing, 4)
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(red: 0.69, green: 0.57, blue: 0.43), Color(red: 0.43, green: 0.31, blue: 0.23), Color(red: 0.31, green: 0.23, blue: 0.18)], startPoint: .top, endPoint: .bottom))
                            .frame(height: 12)
                            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.38)).frame(height: 1) }
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.22)).frame(height: 2) }
                            .shadow(color: ink.opacity(0.18), radius: 5, x: 0, y: 5)
                    }
                }
            }
        }
    }

    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionEyebrow("YOUR READING LIFE", trailing: "02")
            HStack(spacing: 0) {
                ForEach(Array(ReadingStatus.allCases.enumerated()), id: \.element.id) { index, status in
                    NavigationLink {
                        ShelfListView(status: status) { selectedBook = $0 }
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(status.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(muted)
                            Text(String(library.books(for: status).count))
                                .font(.system(size: 30, design: .serif))
                                .foregroundStyle(ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 13)
                        .padding(.leading, index == 0 ? 0 : 13)
                    }
                    if index < ReadingStatus.allCases.count - 1 {
                        Rectangle().fill(ink.opacity(0.12)).frame(width: 1, height: 39)
                    }
                }
            }
            Rectangle().fill(ink.opacity(0.14)).frame(height: 1)
        }
    }

    private var closingNote: some View {
        HStack {
            Text("READ SLOWLY. KEEP THE GOOD ONES.")
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.5)
            Spacer()
            Image(systemName: "leaf")
                .font(.system(size: 12, weight: .light))
        }
        .foregroundStyle(muted.opacity(0.8))
        .padding(.top, 1)
    }

    private func sectionEyebrow(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title).font(.system(size: 8, weight: .bold)).tracking(1.6)
            Spacer()
            Text(trailing).font(.system(size: 8, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(muted)
    }

    @ViewBuilder
    private func homeCover(_ book: Book, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(coverTint(book).gradient)
            if let address = book.coverURL, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        coverTypography(book)
                    }
                }
            } else {
                coverTypography(book)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.black.opacity(0.36), .clear, .white.opacity(0.13)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 9)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(.black.opacity(0.18)).frame(width: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.16), lineWidth: 0.7))
        .shadow(color: ink.opacity(0.19), radius: 8, x: 3, y: 6)
    }

    private func coverTypography(_ book: Book) -> some View {
        VStack(spacing: 7) {
            Rectangle().fill(.white.opacity(0.55)).frame(height: 1)
            Spacer(minLength: 0)
            Text(book.title.uppercased())
                .font(.system(size: 13, weight: .regular, design: .serif))
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .minimumScaleFactor(0.65)
                .foregroundStyle(paper)
            Spacer(minLength: 0)
            Text(book.author.uppercased())
                .font(.system(size: 6, weight: .semibold))
                .tracking(1.2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(paper.opacity(0.82))
            Rectangle().fill(.white.opacity(0.55)).frame(height: 1)
        }
        .padding(9)
    }

    private func coverTint(_ book: Book) -> Color {
        let palette: [Color] = [
            Color(red: 0.35, green: 0.25, blue: 0.22),
            Color(red: 0.22, green: 0.32, blue: 0.27),
            Color(red: 0.62, green: 0.40, blue: 0.28),
            Color(red: 0.28, green: 0.31, blue: 0.40),
            Color(red: 0.52, green: 0.45, blue: 0.34),
            Color(red: 0.43, green: 0.27, blue: 0.29)
        ]
        return palette[abs(book.colorIndex) % palette.count]
    }
}
