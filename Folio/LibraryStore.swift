import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published var books: [Book] = [
        Book(title: "The Secret History", author: "Donna Tartt", status: .reading, colorIndex: 0),
        Book(title: "Piranesi", author: "Susanna Clarke", status: .toRead, colorIndex: 1),
        Book(title: "Tomorrow, and Tomorrow, and Tomorrow", author: "Gabrielle Zevin", status: .finished, colorIndex: 2),
        Book(title: "A Room of One's Own", author: "Virginia Woolf", status: .toRead, colorIndex: 3)
    ]

    func add(title: String, author: String, status: ReadingStatus) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        books.insert(Book(title: cleanTitle, author: cleanAuthor.isEmpty ? "Unknown author" : cleanAuthor, status: status, colorIndex: books.count % 6), at: 0)
    }

    func books(for status: ReadingStatus) -> [Book] {
        books.filter { $0.status == status }
    }
}
