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

    func add(title: String, author: String, status: ReadingStatus, coverURL: String? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        books.insert(Book(title: cleanTitle, author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor, status: status, colorIndex: books.count % 6, coverURL: coverURL), at: 0)
    }

    func update(_ book: Book, status: ReadingStatus) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].status = status
    }

    func remove(_ book: Book) { books.removeAll { $0.id == book.id } }

    func books(for status: ReadingStatus) -> [Book] { books.filter { $0.status == status } }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
