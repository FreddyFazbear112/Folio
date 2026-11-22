import SwiftUI
import WidgetKit

@MainActor
final class LibraryStore: ObservableObject {
    @Published var books: [Book] = [] {
        didSet { save() }
    }
    private let storageKey = "folio.library.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Book].self, from: data) {
            books = saved
        } else {
            books = []
        }
    }

    var continueReadingBook: Book? {
        books
            .filter { $0.status == .reading }
            .sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
            .first ?? books.first
    }

    var favoriteBooks: [Book] {
        books.filter(\.isFavorite)
    }

    var recentlyReadBooks: [Book] {
        books
            .filter { $0.lastOpenedAt != nil || $0.status == .reading || $0.status == .finished }
            .sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
    }

    var recentlyAddedBooks: [Book] {
        books.sorted { $0.addedAt > $1.addedAt }
    }

    func digitalFileURL(for book: Book) -> URL? {
        guard let fileName = book.digitalFileName else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    @discardableResult
    func add(title: String, author: String, status: ReadingStatus, coverURL: String? = nil, isbn: String? = nil) -> UUID? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let normalizedAuthor = cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor
        let cleanISBN = isbn?.uppercased().filter { $0.isNumber || $0 == "X" }
        if let existing = books.first(where: { candidate in
            if let cleanISBN, !cleanISBN.isEmpty {
                return candidate.isbn?.uppercased() == cleanISBN || candidate.ownedISBN?.uppercased() == cleanISBN
            }
            return candidate.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame
                && candidate.author.localizedCaseInsensitiveCompare(normalizedAuthor) == .orderedSame
        }) {
            return existing.id
        }
        let book = Book(
            title: cleanTitle,
            author: normalizedAuthor,
            status: status,
            colorIndex: books.count % 6,
            coverURL: coverURL,
            isbn: cleanISBN,
            addedAt: Date()
        )
        books.insert(book, at: 0)
        return book.id
    }

    func toggleFavorite(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].isFavorite.toggle()
    }

    func markOpened(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].lastOpenedAt = Date()
        if books[index].status == .toRead {
            books[index].status = .reading
        }
    }

    func update(_ book: Book, status: ReadingStatus) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].status = status
    }

    func updateReadingDetails(_ book: Book, currentPage: Int?, totalPages: Int?, note: String?) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].currentPage = currentPage
        books[index].totalPages = totalPages
        books[index].lastOpenedAt = Date()
        if let currentPage, let totalPages, totalPages > 0, currentPage >= totalPages {
            books[index].status = .finished
        } else if (currentPage ?? 0) > 1 && books[index].status == .toRead {
            books[index].status = .reading
        }
        if let note {
            books[index].readingNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func verifyOwnership(_ book: Book, scannedISBN: String) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let clean = scannedISBN.uppercased().filter { $0.isNumber || $0 == "X" }
        guard !clean.isEmpty else { return }
        books[index].ownedISBN = clean
        if books[index].isbn == nil { books[index].isbn = clean }
    }

    func attachDigitalCopy(_ book: Book, fileName: String) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].digitalFileName = fileName
    }

    func updateEdition(_ book: Book, coverURL: String?, spineColorHex: String?, backCoverURL: String?) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].coverURL = coverURL
        books[index].spineColorHex = spineColorHex
        books[index].backCoverURL = backCoverURL
    }

    func remove(_ book: Book) {
        if let fileName = books.first(where: { $0.id == book.id })?.digitalFileName {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documents.appendingPathComponent(fileName).standardizedFileURL
            if fileURL.deletingLastPathComponent() == documents.standardizedFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        books.removeAll { $0.id == book.id }
        UserDefaults.standard.removeObject(forKey: "folio.timer.elapsed.\(book.id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "folio.timer.started.\(book.id.uuidString)")
    }

    func books(for status: ReadingStatus) -> [Book] { books.filter { $0.status == status } }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)

        let shared = UserDefaults(suiteName: "group.com.folio.app")
        let current = continueReadingBook
        shared?.set(current?.title ?? "Choose your next story", forKey: "widget.current.title")
        shared?.set(current?.author ?? "Your Folio library", forKey: "widget.current.author")
        shared?.set(current?.progressFraction ?? 0, forKey: "widget.current.progress")
        WidgetCenter.shared.reloadTimelines(ofKind: "FolioShelfWidget")
    }
}
