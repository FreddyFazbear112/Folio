import Foundation

struct BookLookupService {
    struct SearchResponse: Decodable { let docs: [Document] }
    struct Document: Decodable {
        let title: String?
        let author_name: [String]?
        let first_publish_year: Int?
        let cover_i: Int?
    }

    func lookup(isbn: String) async throws -> (title: String, author: String, coverURL: String?)? {
        let clean = isbn.filter(\.isNumber)
        guard !clean.isEmpty,
              let url = URL(string: "https://openlibrary.org/search.json?isbn=\(clean)&limit=1") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let first = result.docs.first, let title = first.title else { return nil }
        let coverURL = first.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
        return (title, first.author_name?.first ?? "Unknown author", coverURL)
    }
}
