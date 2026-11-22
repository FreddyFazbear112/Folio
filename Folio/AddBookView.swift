import SwiftUI
import VisionKit

private let cataloguePaper = Color(red: 0.955, green: 0.936, blue: 0.885)
private let catalogueInk = Color(red: 0.19, green: 0.21, blue: 0.18)
private let catalogueMuted = Color(red: 0.48, green: 0.47, blue: 0.42)

struct AddBookView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isbn = ""
    @State private var results: [CatalogueBook] = []
    @State private var isSearching = false
    @State private var searchingISBN = false
    @State private var addingIDs: Set<String> = []
    @State private var notice: String?
    @State private var showingScanner = false
    @State private var status: ReadingStatus = .toRead
    @State private var showManualEntry = false
    @State private var manualTitle = ""
    @State private var manualAuthor = ""

    private let service = BookLookupService()

    var body: some View {
        NavigationStack {
            ZStack {
                cataloguePaper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        searchField
                        if let notice {
                            Text(notice)
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(catalogueMuted)
                                .padding(.horizontal, 2)
                        }
                        if isSearching {
                            HStack(spacing: 10) {
                                ProgressView().tint(catalogueInk)
                                Text("Looking through the shelves…")
                                    .font(.system(size: 13, design: .serif).italic())
                                    .foregroundStyle(catalogueMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else if !results.isEmpty {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("FOUND IN THE CATALOGUE")
                                        .font(.system(size: 9, weight: .semibold)).tracking(1.8)
                                    Spacer()
                                    Text("\(results.count) EDITIONS")
                                        .font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(catalogueMuted)
                                }
                                ForEach(results) { book in resultRow(book) }
                            }
                        } else {
                            discoveryNote
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("YOUR SHELF")
                                .font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(catalogueMuted)
                            Picker("Reading status", selection: $status) {
                                ForEach(ReadingStatus.allCases) { item in Text(item.rawValue).tag(item) }
                            }
                            .pickerStyle(.segmented)
                        }

                        Button {
                            showManualEntry = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil.line")
                                Text("Add a book not in the catalogue")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(catalogueInk)
                            .padding(.vertical, 14)
                            .overlay(alignment: .top) { Rectangle().fill(catalogueInk.opacity(0.13)).frame(height: 1) }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 17)
                    .padding(.bottom, 34)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(catalogueInk)
                    Spacer()
                    Text("THE FOLIO CATALOGUE")
                        .font(.system(size: 9, weight: .semibold)).tracking(2)
                        .foregroundStyle(catalogueMuted)
                    Spacer()
                    Image(systemName: "book.closed")
                        .foregroundStyle(catalogueInk)
                        .frame(width: 42)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(cataloguePaper)
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    ISBNScannerView(onScan: { code in
                        isbn = code
                        showingScanner = false
                        Task { await findISBN() }
                    }, onCancel: { showingScanner = false })
                    .ignoresSafeArea()
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showingScanner = false } } }
                }
            }
            .alert("Add a book", isPresented: $showManualEntry) {
                TextField("Title", text: $manualTitle)
                TextField("Author", text: $manualAuthor)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let title = manualTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else {
                        notice = "A book needs a title before it can be added."
                        return
                    }
                    _ = library.add(title: title, author: manualAuthor, status: status)
                    SoundEffects.addBook()
                    dismiss()
                }
            } message: {
                Text("Add its details to your shelf. Folio will keep looking for a digital edition when one is available.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A NEW STORY")
                .font(.system(size: 9, weight: .semibold)).tracking(2.2).foregroundStyle(catalogueMuted)
            Text("Find your next\nworld to wander.")
                .font(.system(size: 34, weight: .regular, design: .serif))
                .tracking(-1.1).lineSpacing(-3).foregroundStyle(catalogueInk)
            Text("Search once. Folio will find the book—and add a free digital edition when one is available.")
                .font(.system(size: 13, design: .serif)).lineSpacing(3)
                .foregroundStyle(catalogueMuted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchField: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(catalogueMuted)
                TextField("Title, author, or series", text: $searchText)
                    .font(.system(size: 15, design: .serif))
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if !searchText.isEmpty {
                    Button { searchText = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(catalogueMuted.opacity(0.7))
                    }
                }
                Button { Task { await search() } } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(cataloguePaper)
                        .frame(width: 34, height: 34)
                        .background(catalogueInk)
                        .clipShape(Circle())
                }
                .disabled(isSearching || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(Color.white.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(catalogueInk.opacity(0.12), lineWidth: 1))
            HStack(spacing: 9) {
                Image(systemName: "barcode.viewfinder")
                TextField("Or enter an ISBN", text: $isbn).keyboardType(.numberPad)
                Button("Find") { Task { await findISBN() } }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(isbn.isEmpty || searchingISBN)
                Button { showingScanner = true } label: {
                    Image(systemName: "camera.viewfinder").font(.system(size: 17))
                }
                .disabled(!DataScannerViewController.isSupported || !DataScannerViewController.isAvailable)
            }
            .font(.system(size: 12))
            .foregroundStyle(catalogueMuted)
            .padding(.horizontal, 4)
        }
    }

    private var discoveryNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle").foregroundStyle(Color(red: 0.62, green: 0.43, blue: 0.30))
                Text("A LIBRARY WITHOUT LIMITS")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.6)
            }
            Text("Thousands of classics are ready to read.")
                .font(.system(size: 19, design: .serif))
                .foregroundStyle(catalogueInk)
            Text("Folio searches the general book catalogue and a public-domain library. When a free EPUB or PDF is available, it can be added straight to your reading shelf.")
                .font(.system(size: 12, design: .serif)).lineSpacing(3)
                .foregroundStyle(catalogueMuted)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.43))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resultRow(_ book: CatalogueBook) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.38, green: 0.31, blue: 0.26))
                if let address = book.coverURL, let url = URL(string: address) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { fallbackCover(book) }
                    }
                } else {
                    fallbackCover(book)
                }
            }
            .frame(width: 65, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.16), radius: 5, x: 2, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(catalogueInk).lineLimit(2)
                Text(book.author)
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(catalogueMuted).lineLimit(1)
                Text(book.sourceLabel.uppercased())
                    .font(.system(size: 8, weight: .medium)).tracking(1)
                    .foregroundStyle(catalogueMuted.opacity(0.85)).lineLimit(1)
                if book.canReadNow {
                    Label("FREE \(book.format ?? "DIGITAL") EDITION", systemImage: "book.pages")
                        .font(.system(size: 8, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(Color(red: 0.28, green: 0.43, blue: 0.32))
                } else {
                    Text("Catalogue record")
                        .font(.system(size: 9, design: .serif)).italic()
                        .foregroundStyle(catalogueMuted.opacity(0.8))
                }
                Spacer(minLength: 2)
                Button {
                    Task { await add(book) }
                } label: {
                    HStack(spacing: 6) {
                        if addingIDs.contains(book.id) { ProgressView().tint(.white).scaleEffect(0.75) }
                        Text(addingIDs.contains(book.id) ? "Adding…" : book.canReadNow ? "Add & download" : "Add to shelf")
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cataloguePaper)
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(catalogueInk)
                    .clipShape(Capsule())
                }
                .disabled(addingIDs.contains(book.id))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.57))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fallbackCover(_ book: CatalogueBook) -> some View {
        VStack(spacing: 5) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
            Spacer(minLength: 0)
            Text(book.title).font(.system(size: 10, design: .serif))
                .multilineTextAlignment(.center).lineLimit(5).foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(book.author.uppercased()).font(.system(size: 5, weight: .medium))
                .tracking(0.7).multilineTextAlignment(.center).lineLimit(2).foregroundStyle(.white.opacity(0.8))
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
        }
        .padding(6)
    }

    @MainActor
    private func search() async {
        isSearching = true
        notice = nil
        defer { isSearching = false }
        do {
            results = try await service.searchCatalogue(query: searchText)
            if results.isEmpty { notice = "No matches yet. Try a title, author, or ISBN." }
        } catch {
            notice = "The catalogue couldn't be reached. Check your connection and try again."
        }
    }

    @MainActor
    private func findISBN() async {
        searchingISBN = true
        notice = nil
        defer { searchingISBN = false }
        do {
            guard BookLookupService.isValidISBN(isbn) else {
                notice = "Enter a valid 10- or 13-digit ISBN, including its check digit."
                return
            }
            if let match = try await service.lookup(isbn: isbn) {
                results = [match]
            } else {
                notice = "We couldn't find that edition. Try searching by title."
            }
        } catch {
            notice = "The catalogue couldn't be reached. Try again in a moment."
        }
    }

    @MainActor
    private func add(_ book: CatalogueBook) async {
        let cleanISBN = book.isbn?.uppercased().filter { $0.isNumber || $0 == "X" }
        let alreadyOnShelf = library.books.contains { saved in
            if let cleanISBN, !cleanISBN.isEmpty {
                return saved.isbn?.uppercased() == cleanISBN || saved.ownedISBN?.uppercased() == cleanISBN
            }
            return saved.title.localizedCaseInsensitiveCompare(book.title) == .orderedSame
                && saved.author.localizedCaseInsensitiveCompare(book.author) == .orderedSame
        }
        if alreadyOnShelf {
            notice = "That book is already on your shelf."
            return
        }
        addingIDs.insert(book.id)
        defer { addingIDs.remove(book.id) }
        guard let id = library.add(title: book.title, author: book.author, status: status, coverURL: book.coverURL, isbn: book.isbn) else { return }
        if book.canReadNow {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = folder.appendingPathComponent(id.uuidString)
            do {
                if let filename = try await service.download(book, to: destination),
                   let saved = library.books.first(where: { $0.id == id }) {
                    library.attachDigitalCopy(saved, fileName: filename)
                    notice = "Your free digital edition is ready on your shelf."
                }
            } catch {
                notice = "The book is on your shelf, but its download didn't finish. You can try again later."
            }
        } else {
            notice = "Added to your shelf. A downloadable edition isn't currently listed for this title."
        }
        SoundEffects.addBook()
        if book.canReadNow { dismiss() }
    }
}
