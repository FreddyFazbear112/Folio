import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import QuickLook

private let folioPaper = Color(red: 0.96, green: 0.94, blue: 0.89)
private let folioInk = Color(red: 0.18, green: 0.20, blue: 0.17)

struct ContentView: View {
    @AppStorage("folio.hasCompletedOnboarding.v2") private var hasWelcomed = false

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
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedBook: Book?
    @State private var showingAddBook = false
    @State private var selectedTab = 0

    private let background = Color(red: 0.055, green: 0.052, blue: 0.049)
    private let cream = Color(red: 0.94, green: 0.90, blue: 0.82)
    private let gold = Color(red: 0.79, green: 0.62, blue: 0.39)

    var body: some View {
        TabView(selection: $selectedTab) {
            FolioLibraryHome(
                selectBook: { selectedBook = $0 },
                addBook: { showingAddBook = true },
                openLibrary: { selectedTab = 1 },
                openMore: { selectedTab = 4 }
            )
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            FolioLibraryScreen(selectBook: { selectedBook = $0 }, addBook: { showingAddBook = true })
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(1)

            FolioDiscoverScreen(addBook: { showingAddBook = true })
                .tabItem { Label("Discover", systemImage: "sparkle.magnifyingglass") }
                .tag(2)

            FolioStatsScreen()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(3)

            ProfileView()
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(4)
        }
        .tint(gold)
        .preferredColorScheme(.dark)
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book)
                .environmentObject(library)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddBook) {
            AddBookView()
                .environmentObject(library)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct ShelfListView: View {
    @EnvironmentObject private var library: LibraryStore
    let status: ReadingStatus
    let select: (Book) -> Void

    private let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

    var body: some View {
        ZStack {
            folioPaper.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR FOLIO COLLECTION")
                            .font(.system(size: 8, weight: .semibold)).tracking(2)
                            .foregroundStyle(folioInk.opacity(0.48))
                        Text(status.rawValue)
                            .font(.system(size: 34, design: .serif)).tracking(-0.8)
                            .foregroundStyle(folioInk)
                        Text("\(library.books(for: status).count) books in this chapter")
                            .font(.system(size: 12, design: .serif)).italic()
                            .foregroundStyle(folioInk.opacity(0.55))
                    }
                    if library.books(for: status).isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 30, weight: .ultraLight))
                            Text("This shelf is waiting.")
                                .font(.system(size: 21, design: .serif))
                            Text("Books you mark as \(status.rawValue.lowercased()) will find a home here.")
                                .font(.system(size: 12, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(folioInk.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 58)
                        .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                            ForEach(library.books(for: status)) { book in
                                Button { select(book) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.39, green: 0.28, blue: 0.22))
                                            if let address = book.coverURL, let url = URL(string: address) {
                                                AsyncImage(url: url) { phase in
                                                    if let image = phase.image { image.resizable().scaledToFill() }
                                                    else { coverFallback(book) }
                                                }
                                            } else { coverFallback(book) }
                                        }
                                        .frame(maxWidth: .infinity).aspectRatio(0.69, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(alignment: .leading) {
                                            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 8)
                                        }
                                        .shadow(color: folioInk.opacity(0.16), radius: 7, x: 3, y: 5)
                                        Text(book.title)
                                            .font(.system(size: 13, design: .serif))
                                            .foregroundStyle(folioInk).lineLimit(2).multilineTextAlignment(.leading)
                                        Text(book.author.uppercased())
                                            .font(.system(size: 7, weight: .medium)).tracking(1)
                                            .foregroundStyle(folioInk.opacity(0.52)).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 36)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func coverFallback(_ book: Book) -> some View {
        VStack(spacing: 7) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
            Spacer(minLength: 0)
            Text(book.title).font(.system(size: 12, design: .serif))
                .multilineTextAlignment(.center).lineLimit(5).foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(book.author.uppercased()).font(.system(size: 6, weight: .medium))
                .tracking(0.8).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
        }
        .padding(8)
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
    @State private var confirmingRemoval = false
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
                bookHeading
                bookPreview
                editionStudio
                readingCopySection
                readingTimerSection
                journalSection
                shelfSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .background(folioPaper.ignoresSafeArea())
        .confirmationDialog("Remove this book?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove from my shelf", role: .destructive) { library.remove(book); dismiss() }
            Button("Keep book", role: .cancel) {}
        } message: {
            Text("This removes the book and its reading details from this device.")
        }
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

            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, UTType(filenameExtension: "epub") ?? .data, .plainText, .rtf, .html], allowsMultipleSelection: false) { result in
            importCopy(result)
        }
        .fullScreenCover(isPresented: $reading) {
            if let readerURL {
                if readerURL.pathExtension.lowercased() == "pdf" {
                    Folio3DBookReader(
                        url: readerURL,
                        title: savedBook.title,
                        coverURL: savedBook.coverURL,
                        initialPage: book.currentPage ?? 1
                    ) { page, total in
                        currentPageText = String(page)
                        totalPagesText = String(total)
                        library.updateReadingDetails(book, currentPage: page, totalPages: total, note: readingNote)
                    }
                } else {
                    FolioReadingCopyView(url: readerURL, initialPage: book.currentPage ?? 1) { page, total in
                        currentPageText = String(page)
                        totalPagesText = String(total)
                        library.updateReadingDetails(book, currentPage: page, totalPages: total, note: readingNote)
                    }
                }
            }
        }
    }

    private var bookHeading: some View {
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
    }

    private var bookPreview: some View {
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
    }

    private var editionStudio: some View {
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
    }

    private var readingCopySection: some View {
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
                    } else {
                        Text("Add a digital copy you already own. Folio keeps the file on this iPhone and opens it in the reader.")
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
                    if let fileName = savedBook.digitalFileName {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(red: 0.34, green: 0.43, blue: 0.34))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DIGITAL COPY ON THIS IPHONE")
                                    .font(.system(size: 8, weight: .semibold)).tracking(1.1)
                                Text(fileName)
                                    .font(.system(size: 10, design: .serif))
                                    .foregroundStyle(folioInk.opacity(0.58)).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.34, green: 0.43, blue: 0.34))
                        }
                        .padding(13)
                        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 9))
                        actionRow("Read this book", symbol: "book.pages", prominent: true) { openReader() }
                        actionRow("Replace digital copy", symbol: "arrow.triangle.2.circlepath") { importing = true }
                    } else {
                        actionRow("Import a digital reading copy", symbol: "square.and.arrow.down") { importing = true }
                    }
                    if let message { Text(message).font(.system(size: 12, design: .serif)).foregroundStyle(.secondary) }
                }
    }

    private var readingTimerSection: some View {
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
    }

    private var journalSection: some View {
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
    }

    private var shelfSection: some View {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("ON YOUR SHELF")
                    Picker("Reading status", selection: Binding(get: { savedBook.status }, set: { library.update(book, status: $0) })) {
                        ForEach(ReadingStatus.allCases) { status in Text(status.rawValue).tag(status) }
                    }.pickerStyle(.segmented)
                    Button(role: .destructive) { confirmingRemoval = true } label: {
                        Label("Remove from shelf", systemImage: "trash").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.top, 5)
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
        let clean = code.uppercased().filter { $0.isNumber || $0 == "X" }
        if let isbn = savedBook.isbn, isbn.uppercased() == clean {
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
            guard ["pdf", "epub", "txt", "rtf", "html", "htm"].contains(ext) else { message = "Choose an EPUB, PDF, TXT, RTF, or HTML reading file."; return }
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let previousFileName = savedBook.digitalFileName
            let destination = folder.appendingPathComponent(book.id.uuidString + "." + ext)
            let stagedCopy = folder.appendingPathComponent("\(book.id.uuidString)-\(UUID().uuidString).import")
            defer { try? FileManager.default.removeItem(at: stagedCopy) }
            try FileManager.default.copyItem(at: source, to: stagedCopy)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: stagedCopy)
            } else {
                try FileManager.default.moveItem(at: stagedCopy, to: destination)
            }
            library.attachDigitalCopy(book, fileName: destination.lastPathComponent)
            if let previousFileName, previousFileName != destination.lastPathComponent {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(previousFileName))
            }
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
    let initialPage: Int
    var onProgress: (Int, Int) -> Void
    @State private var currentPage: Int
    init(url: URL, initialPage: Int = 1, onProgress: @escaping (Int, Int) -> Void) {
        self.url = url
        self.initialPage = max(1, initialPage)
        self.onProgress = onProgress
        _currentPage = State(initialValue: max(1, initialPage))
    }
    @State private var totalPages = 0
    @State private var sepia = true
    @State private var focusMode = false
    @State private var textFontSize: CGFloat = 19

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
                        if !["pdf", "epub"].contains(url.pathExtension.lowercased()) {
                            HStack(spacing: 3) {
                                Button { textFontSize = max(14, textFontSize - 1) } label: {
                                    Image(systemName: "textformat.size.smaller")
                                        .frame(width: 30, height: 34)
                                }
                                Button { textFontSize = min(30, textFontSize + 1) } label: {
                                    Image(systemName: "textformat.size.larger")
                                        .frame(width: 30, height: 34)
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .background(.white.opacity(0.45), in: Capsule())
                            .accessibilityElement(children: .contain)
                        }
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
                let fileType = url.pathExtension.lowercased()
                if fileType == "pdf" {
                    FolioPDFView(url: url, currentPage: $currentPage, totalPages: $totalPages, sepia: sepia)
                        .ignoresSafeArea(edges: focusMode ? .all : [])
                } else if fileType == "epub" {
                    FolioEPUBReader(url: url, sepia: sepia, initialChapter: max(0, initialPage - 1), onProgress: onProgress)
                } else {
                    FolioTextReader(url: url, sepia: sepia, fontSize: textFontSize)
                }
                if fileType == "pdf" && !focusMode {
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

private struct FolioTextReader: UIViewRepresentable {
    let url: URL
    let sepia: Bool
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 30, left: 24, bottom: 44, right: 24)
        view.backgroundColor = sepia
            ? UIColor(red: 0.91, green: 0.87, blue: 0.78, alpha: 1)
            : UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1)
        view.textColor = sepia
            ? UIColor(red: 0.18, green: 0.20, blue: 0.17, alpha: 1)
            : UIColor(red: 0.94, green: 0.92, blue: 0.87, alpha: 1)
        view.font = UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
        view.text = "Opening your document…"
        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            if ext == "rtf" || ext == "html" || ext == "htm" {
                let kind: NSAttributedString.DocumentType = ext == "rtf" ? .rtf : .html
                let document = try NSAttributedString(data: data, options: [.documentType: kind], documentAttributes: nil)
                let mutable = NSMutableAttributedString(attributedString: document)
                mutable.addAttributes([.foregroundColor: view.textColor ?? .label, .font: view.font ?? UIFont.systemFont(ofSize: 19)], range: NSRange(location: 0, length: mutable.length))
                view.attributedText = mutable
            } else {
                view.text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? "Unsupported text encoding."
            }
        } catch {
            view.text = "This document couldn't be opened: \(error.localizedDescription)"
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.backgroundColor = sepia
            ? UIColor(red: 0.91, green: 0.87, blue: 0.78, alpha: 1)
            : UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1)
        let ink = sepia
            ? UIColor(red: 0.18, green: 0.20, blue: 0.17, alpha: 1)
            : UIColor(red: 0.94, green: 0.92, blue: 0.87, alpha: 1)
        view.textColor = ink
        view.font = UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
        if view.attributedText.length > 0 {
            let styled = NSMutableAttributedString(attributedString: view.attributedText)
            styled.addAttributes([.font: view.font ?? UIFont.systemFont(ofSize: fontSize), .foregroundColor: ink], range: NSRange(location: 0, length: styled.length))
            view.attributedText = styled
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
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.17), Color(red: 0.075, green: 0.09, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().stroke(Color(red: 0.79, green: 0.63, blue: 0.40).opacity(0.18), lineWidth: 1)
                        .frame(width: 235, height: 235).offset(x: 115, y: -72)
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.24), Color(red: 0.24, green: 0.18, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.17)).frame(width: 3) }
                            .overlay {
                                VStack(spacing: 12) {
                                    Image(systemName: steps[page].symbol).font(.system(size: 29, weight: .ultraLight))
                                    Text("FOLIO").font(.system(size: 11, weight: .semibold, design: .serif)).tracking(2.5)
                                }.foregroundStyle(Color(red: 0.94, green: 0.83, blue: 0.66))
                            }
                            .frame(width: 112, height: 158)
                            .rotation3DEffect(.degrees(-13), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
                            .shadow(color: .black.opacity(0.42), radius: 17, x: 8, y: 12)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(["YOUR SHELF", "SCAN AN EDITION", "MAKE IT YOURS", "OPEN THE STORY", "A READING RITUAL"][page])
                                .font(.system(size: 8, weight: .bold)).tracking(1.2)
                                .foregroundStyle(Color(red: 0.85, green: 0.70, blue: 0.48))
                            ForEach(0..<5, id: \.self) { line in
                                Capsule().fill(Color.white.opacity(line == 0 ? 0.56 : 0.17))
                                    .frame(width: CGFloat([91, 74, 86, 62, 78][line]), height: 3)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "bookmark.fill").font(.system(size: 12)).foregroundStyle(Color(red: 0.85, green: 0.70, blue: 0.48))
                        }
                        .padding(13).frame(width: 120, height: 158, alignment: .leading)
                        .background(Color(red: 0.88, green: 0.83, blue: 0.73))
                        .rotation3DEffect(.degrees(8), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
                        .shadow(color: .black.opacity(0.3), radius: 14, x: -5, y: 10)
                    }
                    .offset(y: 3)
                    VStack {
                        HStack {
                            Text("A LITTLE GUIDE").font(.system(size: 8, weight: .bold)).tracking(1.8)
                            Spacer()
                            Text("0\(page + 1) / 05").font(.system(size: 8, weight: .medium, design: .monospaced))
                        }
                        Spacer()
                    }
                    .foregroundStyle(Color.white.opacity(0.55)).padding(17)
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: ink.opacity(0.14), radius: 18, x: 0, y: 10)
                .padding(.bottom, 30)

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

private enum FolioPalette {
    static let background = Color(red: 0.055, green: 0.052, blue: 0.049)
    static let surface = Color(red: 0.115, green: 0.108, blue: 0.100)
    static let raised = Color(red: 0.155, green: 0.145, blue: 0.133)
    static let cream = Color(red: 0.94, green: 0.91, blue: 0.85)
    static let muted = Color(red: 0.66, green: 0.62, blue: 0.56)
    static let gold = Color(red: 0.80, green: 0.64, blue: 0.43)
    static let line = Color.white.opacity(0.09)
}

private struct FolioLibraryHome: View {
    @EnvironmentObject private var library: LibraryStore
    let selectBook: (Book) -> Void
    let addBook: () -> Void
    let openLibrary: () -> Void
    let openMore: () -> Void

    private var currentlyReading: Book? { library.books.first(where: { $0.status == .reading }) }
    private var recentBooks: [Book] { Array(library.books.prefix(8)) }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        if hour < 18 { return "Good afternoon," }
        return "Good evening,"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    greetingBlock
                    continueReading
                    shortcuts
                    recentlyAdded
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(FolioPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Text("Folio")
                .font(.system(size: 31, weight: .regular, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(FolioPalette.cream)
            Spacer()
            Button(action: openMore) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(FolioPalette.gold)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Profile and account")
        }
        .padding(.top, 2)
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(greeting)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(FolioPalette.cream)
            Text("Reader. 👋")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(FolioPalette.cream)
        }
        .padding(.top, 0)
    }

    @ViewBuilder
    private var continueReading: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Continue Reading", action: nil)
            if let book = currentlyReading {
                Button { selectBook(book) } label: {
                    HStack(spacing: 14) {
                        FolioBookCover(book: book)
                            .frame(width: 76, height: 108)
                            .shadow(color: .black.opacity(0.35), radius: 9, x: 3, y: 5)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Continue Reading")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FolioPalette.cream)
                            Text(book.title)
                                .font(.system(size: 17, design: .serif))
                                .foregroundStyle(FolioPalette.cream)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(book.author)
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(FolioPalette.muted)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let page = book.currentPage, let total = book.totalPages, total > 0 {
                                ProgressView(value: min(1, Double(page) / Double(total)))
                                    .tint(FolioPalette.gold)
                                Text("\(Int((Double(page) / Double(total) * 100).rounded()))% • \(max(1, Int(Double(total - page) * 0.06)))h left")
                                    .font(.system(size: 10, design: .rounded).monospacedDigit())
                                    .foregroundStyle(FolioPalette.muted)
                            } else {
                                Text(book.digitalFileName == nil ? "Add your digital copy to read" : "Continue your story")
                                    .font(.system(size: 10, design: .serif))
                                    .foregroundStyle(FolioPalette.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FolioPalette.background)
                            .frame(width: 34, height: 34)
                            .background(FolioPalette.gold, in: Circle())
                    }
                    .padding(14)
                    .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(FolioPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: addBook) {
                    HStack(spacing: 13) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(FolioPalette.gold)
                            .frame(width: 70, height: 94)
                            .background(FolioPalette.raised, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your next chapter starts here")
                                .font(.system(size: 17, design: .serif))
                                .foregroundStyle(FolioPalette.cream)
                            Text("Add a book to begin reading.")
                                .font(.system(size: 11, design: .serif))
                                .foregroundStyle(FolioPalette.muted)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(FolioPalette.gold)
                    }
                    .padding(14)
                    .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Your Library", action: "See all  ›", perform: openLibrary)
            HStack(spacing: 10) {
                shortcut(title: "All Books", count: "\(library.books.count)", symbol: "book.closed", action: openLibrary)
                shortcut(title: "Favorites", count: "\(library.books.filter { $0.isFavorite == true }.count)", symbol: "star.fill", action: openLibrary)
                shortcut(title: "Recently Read", count: "\(library.books(for: .finished).count)", symbol: "clock.arrow.circlepath", action: openLibrary)
            }
        }
    }

    private func shortcut(title: String, count: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(FolioPalette.gold)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(FolioPalette.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(count)
                    .font(.system(size: 10, design: .rounded).monospacedDigit())
                    .foregroundStyle(FolioPalette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 91, alignment: .center)
            .padding(12)
            .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var recentlyAdded: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Recently Added", action: "See all  ›", perform: openLibrary)
            if recentBooks.isEmpty {
                Button(action: addBook) {
                    HStack {
                        Image(systemName: "plus").foregroundStyle(FolioPalette.gold)
                        Text("Your shelves are waiting. Add your first book.")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(FolioPalette.muted)
                        Spacer()
                    }
                    .padding(16)
                    .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 13) {
                        ForEach(recentBooks) { book in
                            Button { selectBook(book) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    FolioBookCover(book: book)
                                        .frame(width: 104, height: 148)
                                        .shadow(color: .black.opacity(0.35), radius: 8, x: 3, y: 5)
                                    Text(book.title)
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundStyle(FolioPalette.cream)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 104, alignment: .leading)
                                    Text(book.author)
                                        .font(.system(size: 9, design: .serif))
                                        .foregroundStyle(FolioPalette.muted)
                                        .lineLimit(1)
                                        .frame(width: 104, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, action: String?, perform: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(FolioPalette.muted)
            Spacer()
            if let action, let perform {
                Button(action, action: perform)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(FolioPalette.gold)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Rectangle().fill(FolioPalette.line).frame(height: 1)
            Text("READ. EXPLORE. BELONG.")
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(FolioPalette.muted)
            Rectangle().fill(FolioPalette.line).frame(height: 1)
        }
        .padding(.top, 5)
    }
}

private struct FolioLibraryScreen: View {
    @EnvironmentObject private var library: LibraryStore
    let selectBook: (Book) -> Void
    let addBook: () -> Void
    @State private var searchText = ""
    @State private var format = "All"
    private let formats = ["All", "EPUB", "PDF", "TXT"]

    private var filteredBooks: [Book] {
        library.books.filter { book in
            let queryMatches = searchText.isEmpty || book.title.localizedCaseInsensitiveContains(searchText) || book.author.localizedCaseInsensitiveContains(searchText)
            let ext = book.digitalFileName.map { ($0 as NSString).pathExtension.uppercased() } ?? ""
            let formatMatches = format == "All" || ext == format
            return queryMatches && formatMatches
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Library")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(FolioPalette.muted)
                        TextField("Search your library…", text: $searchText)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                    }
                    .padding(13)
                    .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 8) {
                        ForEach(formats, id: \.self) { item in
                            Button { format = item } label: {
                                Text(item)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(format == item ? FolioPalette.background : FolioPalette.muted)
                                    .padding(.horizontal, 17).padding(.vertical, 9)
                                    .background(format == item ? FolioPalette.gold : FolioPalette.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if filteredBooks.isEmpty {
                        ContentUnavailableView("No books here yet", systemImage: "books.vertical", description: Text("Import an EPUB, PDF or text file, or add a title to your collection."))
                            .foregroundStyle(FolioPalette.muted)
                            .frame(maxWidth: .infinity).padding(.top, 34)
                        Button(action: addBook) {
                            Label("Add a book", systemImage: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FolioPalette.background)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(FolioPalette.gold, in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredBooks) { book in
                                Button { selectBook(book) } label: {
                                    HStack(spacing: 13) {
                                        FolioBookCover(book: book).frame(width: 58, height: 82)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(book.title).font(.system(size: 15, design: .serif)).foregroundStyle(FolioPalette.cream).lineLimit(2)
                                            Text(book.author).font(.system(size: 11, design: .serif)).foregroundStyle(FolioPalette.muted)
                                            Text(book.digitalFileName.map { $0.uppercased() } ?? book.status.rawValue.uppercased())
                                                .font(.system(size: 8, weight: .medium)).tracking(0.8).foregroundStyle(FolioPalette.gold).lineLimit(1)
                                            if let page = book.currentPage, let total = book.totalPages, total > 0 {
                                                Text("\(page) of \(total) pages").font(.system(size: 9)).foregroundStyle(FolioPalette.muted)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "ellipsis").foregroundStyle(FolioPalette.muted)
                                    }
                                    .padding(.vertical, 11)
                                }
                                .buttonStyle(.plain)
                                if book.id != filteredBooks.last?.id { Divider().overlay(FolioPalette.line) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
            }
            .background(FolioPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct FolioDiscoverScreen: View {
    let addBook: () -> Void
    private let categories: [(String, String, String)] = [
        ("Fantasy", "sparkles", "Myth, magic and faraway worlds"),
        ("Mystery", "eye", "Secrets, clues and unexpected turns"),
        ("Science Fiction", "moon.stars", "Ideas about tomorrow"),
        ("Classics", "text.book.closed", "Stories that stay with us")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Discover")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    Button(action: addBook) {
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(colors: [Color(red: 0.24, green: 0.29, blue: 0.27), Color(red: 0.12, green: 0.16, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            VStack(alignment: .leading, spacing: 9) {
                                Text("A GOOD BOOK\nCHANGES THE VIEW.")
                                    .font(.system(size: 25, design: .serif))
                                    .foregroundStyle(FolioPalette.cream)
                                Text("Find a title and bring it to your library.")
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("EXPLORE BOOKS  →")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(FolioPalette.gold)
                            }
                            .padding(20)
                        }
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    Text("Browse by mood")
                        .font(.system(size: 23, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                        ForEach(categories, id: \.0) { category in
                            Button(action: addBook) {
                                VStack(alignment: .leading, spacing: 11) {
                                    Image(systemName: category.1).font(.system(size: 20)).foregroundStyle(FolioPalette.gold)
                                    Text(category.0).font(.system(size: 16, design: .serif)).foregroundStyle(FolioPalette.cream)
                                    Text(category.2).font(.system(size: 10, design: .serif)).foregroundStyle(FolioPalette.muted).multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                                .padding(14)
                                .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(FolioPalette.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Discover opens the book search so you can add titles directly to your own shelves.")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(FolioPalette.muted)
                }
                .padding(20)
            }
            .background(FolioPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct FolioStatsScreen: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your reading")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    HStack(spacing: 10) {
                        statCard("Books", value: library.books.count, symbol: "books.vertical")
                        statCard("Reading", value: library.books(for: .reading).count, symbol: "book.open")
                    }
                    HStack(spacing: 10) {
                        statCard("To Read", value: library.books(for: .toRead).count, symbol: "bookmark")
                        statCard("Finished", value: library.books(for: .finished).count, symbol: "checkmark.seal")
                    }
                    Text("Every book is another place you've been.")
                        .font(.system(size: 16, design: .serif).italic())
                        .foregroundStyle(FolioPalette.muted)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(FolioPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func statCard(_ title: String, value: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol).foregroundStyle(FolioPalette.gold)
            Text("\(value)").font(.system(size: 32, design: .serif)).foregroundStyle(FolioPalette.cream)
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(FolioPalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(16)
        .background(FolioPalette.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FolioBookCover: View {
    let book: Book
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(tint.gradient)
            if let address = book.coverURL, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallback }
                }
            } else { fallback }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.black.opacity(0.38), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 8)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.10), lineWidth: 0.8))
    }

    private var fallback: some View {
        VStack(spacing: 6) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
            Spacer(minLength: 0)
            Text(book.title.uppercased())
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(red: 0.96, green: 0.91, blue: 0.81))
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 0)
            Text(book.author.uppercased())
                .font(.system(size: 6, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
        }
        .padding(8)
    }

    private var tint: Color {
        if let hex = book.spineColorHex, let value = UInt64(hex, radix: 16) {
            return Color(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
        }
        let colors: [Color] = [
            Color(red: 0.35, green: 0.25, blue: 0.22),
            Color(red: 0.22, green: 0.32, blue: 0.27),
            Color(red: 0.62, green: 0.40, blue: 0.28),
            Color(red: 0.28, green: 0.31, blue: 0.40),
            Color(red: 0.52, green: 0.45, blue: 0.34)
        ]
        return colors[abs(book.colorIndex) % colors.count]
    }
}

