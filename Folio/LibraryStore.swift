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
            books = [
                Book(title: "The Secret History", author: "Donna Tartt", status: .reading, colorIndex: 0),
                Book(title: "Piranesi", author: "Susanna Clarke", status: .toRead, colorIndex: 1),
                Book(title: "Tomorrow, and Tomorrow, and Tomorrow", author: "Gabrielle Zevin", status: .finished, colorIndex: 2),
                Book(title: "A Room of One's Own", author: "Virginia Woolf", status: .toRead, colorIndex: 3)
            ]
        }
    }

    func add(title: String, author: String, status: ReadingStatus) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        books.insert(Book(title: cleanTitle, author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor, status: status, colorIndex: books.count % 6), at: 0)
    }

    func update(_ book: Book, status: ReadingStatus) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].status = status
    }

    func books(for status: ReadingStatus) -> [Book] { books.filter { $0.status == status } }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
