import SwiftUI
import VisionKit

struct AddBookView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var searchText = ""
    @State private var coverURL: String?
    @State private var status: ReadingStatus = .toRead
    @State private var showingScanner = false
    @State private var isLookingUp = false
    @State private var lookupMessage: String?
    @State private var lookupTask: Task<Void, Never>?

    private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)

    var body: some View {
        NavigationStack {
            Form {
                Section("FIND A BOOK") {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search title or author", text: $searchText)
                            .submitLabel(.search)
                            .onSubmit { Task { await searchBook() } }
                    }
                    Button {
                        Task { await searchBook() }
                    } label: {
                        HStack {
                            if isLookingUp { ProgressView() }
                            Text("Search the book catalogue")
                        }
                    }
                    .disabled(isLookingUp || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Divider()
                    HStack {
                        TextField("ISBN barcode number", text: $isbn).keyboardType(.numberPad)
                        Button { showingScanner = true } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                        }
                        .disabled(!DataScannerViewController.isSupported || !DataScannerViewController.isAvailable)
                    }
                    Button {
                        Task { await lookupBook() }
                    } label: {
                        Text("Find by ISBN")
                    }
                    .disabled(isLookingUp || isbn.isEmpty)
                    if let lookupMessage {
                        Text(lookupMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("THE BOOK") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("A LITTLE PREVIEW") {
                        BookPreview3D(title: title, tint: UIColor(red: 0.43, green: 0.31, blue: 0.27, alpha: 1), coverURL: coverURL)
                            .frame(height: 165)
                            .listRowInsets(EdgeInsets())
                    }
                }
                Section("YOUR SHELF") {
                    Picker("Reading status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button {
                        library.add(title: title, author: author, status: status, coverURL: coverURL, isbn: isbn)
                        SoundEffects.addBook()
                        dismiss()
                    } label: {
                        Text("Add to my bookshelf")
                            .font(.system(.body, design: .serif).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(ink)
                    .foregroundStyle(paper)
                }
            }
            .scrollContentBackground(.hidden)
            .background(paper)
            .navigationTitle("A new story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.foregroundStyle(ink) }
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    ISBNScannerView(onScan: { code in
                        isbn = code
                        showingScanner = false
                        Task { await lookupBook() }
                    }, onCancel: { showingScanner = false })
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showingScanner = false } }
                    }
                }
            }
        }
    }

    @MainActor
    private func searchBook() async {
        isLookingUp = true
        lookupMessage = "Searching the catalogue…"
        defer { isLookingUp = false }
        do {
            if let result = try await BookLookupService().search(query: searchText) {
                title = result.title
                author = result.author
                coverURL = result.coverURL
                lookupMessage = "Found a match. Check the details before adding it."
            } else {
                lookupMessage = "No match found. You can enter the details yourself."
            }
        } catch {
            lookupMessage = "The catalogue is unavailable. You can still add this book manually."
        }
    }

    @MainActor
    private func lookupBook() async {
        isLookingUp = true
        lookupMessage = "Looking through the catalogue…"
        defer { isLookingUp = false }
        do {
            if let result = try await BookLookupService().lookup(isbn: isbn) {
                title = result.title
                author = result.author
                coverURL = result.coverURL
                lookupMessage = "Found it. Have a look and add it to your shelf."
            } else {
                lookupMessage = "No match found. You can enter the details yourself."
            }
        } catch {
            lookupMessage = "Couldn’t reach the catalogue. You can still add it manually."
        }
    }
}
