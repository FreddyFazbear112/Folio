import SwiftUI

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

    @discardableResult
    func add(title: String, author: String, status: ReadingStatus, coverURL: String? = nil, isbn: String? = nil) -> UUID? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let book = Book(title: cleanTitle, author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor, status: status, colorIndex: books.count % 6, coverURL: coverURL, isbn: isbn?.filter(\.isNumber))
        books.insert(book, at: 0)
        return book.id
    }

    func update(_ book: Book, status: ReadingStatus) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].status = status
    }

    func updateReadingDetails(_ book: Book, currentPage: Int?, totalPages: Int?, note: String?) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].currentPage = currentPage
        books[index].totalPages = totalPages
        books[index].readingNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func verifyOwnership(_ book: Book, scannedISBN: String) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let clean = scannedISBN.filter(\.isNumber)
        guard !clean.isEmpty else { return }
        books[index].ownedISBN = clean
        if books[index].isbn == nil { books[index].isbn = clean }
    }

    func attachDigitalCopy(_ book: Book, fileName: String) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].digitalFileName = fileName
    }

    func updateEdition(_ book: Book, spineColorHex: String?, backCoverURL: String?) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].spineColorHex = spineColorHex
        books[index].backCoverURL = backCoverURL
    }

    func remove(_ book: Book) { books.removeAll { $0.id == book.id } }

    func books(for status: ReadingStatus) -> [Book] { books.filter { $0.status == status } }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
