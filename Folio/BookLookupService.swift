import Foundation

struct CatalogueBook: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let coverURL: String?
    let isbn: String?
    let publicationYear: Int?
    let downloadableURL: URL?
    let format: String?
    let sourceLabel: String
    var canReadNow: Bool { downloadableURL != nil }
}

struct BookLookupService {
    private struct OpenLibraryResponse: Decodable { let docs: [OpenLibraryDocument] }
    private struct OpenLibraryDocument: Decodable {
        let key: String?
        let title: String?
        let author_name: [String]?
        let first_publish_year: Int?
        let cover_i: Int?
        let isbn: [String]?
    }
    private struct GutendexResponse: Decodable { let results: [GutendexBook] }
    private struct GutendexBook: Decodable {
        let id: Int
        let title: String
        let authors: [GutendexAuthor]
        let formats: [String: String]
    }
    private struct GutendexAuthor: Decodable { let name: String }

    func searchCatalogue(query: String) async throws -> [CatalogueBook] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        async let libraryTask = searchOpenLibrary(clean)
        async let publicDomainTask = searchGutendex(clean)
        let (libraryBooks, publicBooks) = try await (libraryTask, publicDomainTask)
        var results = publicBooks
        for item in libraryBooks {
            if !results.contains(where: { $0.title.localizedCaseInsensitiveCompare(item.title) == .orderedSame && $0.author.localizedCaseInsensitiveCompare(item.author) == .orderedSame }) {
                results.append(item)
            }
        }
        return Array(results.prefix(24))
    }

    func lookup(isbn: String) async throws -> CatalogueBook? {
        let clean = isbn.filter(\.isNumber)
        guard !clean.isEmpty else { return nil }
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [URLQueryItem(name: "isbn", value: clean), URLQueryItem(name: "limit", value: "1")]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
        guard let doc = response.docs.first, let title = doc.title else { return nil }
        return CatalogueBook(id: doc.key ?? clean, title: title, author: doc.author_name?.first ?? "Unknown author",
            coverURL: doc.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" },
            isbn: doc.isbn?.first ?? clean, publicationYear: doc.first_publish_year,
            downloadableURL: nil, format: nil, sourceLabel: "Open Library")
    }

    func download(_ book: CatalogueBook, to destination: URL) async throws -> String? {
        guard let url = book.downloadableURL else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.setValue("Folio reading app", forHTTPHeaderField: "User-Agent")
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let finalURL = destination.appendingPathExtension(book.format == "PDF" ? "pdf" : "epub")
        if FileManager.default.fileExists(atPath: finalURL.path) { try FileManager.default.removeItem(at: finalURL) }
        try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        return finalURL.lastPathComponent
    }

    private func searchOpenLibrary(_ query: String) async throws -> [CatalogueBook] {
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "18")]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
        return response.docs.compactMap { doc in
            guard let title = doc.title else { return nil }
            return CatalogueBook(id: doc.key ?? title, title: title, author: doc.author_name?.first ?? "Unknown author",
                coverURL: doc.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" },
                isbn: doc.isbn?.first, publicationYear: doc.first_publish_year, downloadableURL: nil, format: nil, sourceLabel: "Book catalogue")
        }
    }

    private func searchGutendex(_ query: String) async throws -> [CatalogueBook] {
        var components = URLComponents(string: "https://gutendex.com/books/")
        components?.queryItems = [URLQueryItem(name: "search", value: query), URLQueryItem(name: "page", value: "1")]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GutendexResponse.self, from: data)
        return response.results.compactMap { item in
            let epub = item.formats["application/epub+zip"]
            let pdf = item.formats["application/pdf"]
            guard let link = epub ?? pdf, let downloadURL = URL(string: link) else { return nil }
            return CatalogueBook(id: "gutenberg-\(item.id)", title: item.title, author: item.authors.first?.name ?? "Unknown author",
                coverURL: nil, isbn: nil, publicationYear: nil, downloadableURL: downloadURL,
                format: epub == nil ? "PDF" : "EPUB", sourceLabel: "Project Gutenberg · Public domain")
        }
    }
}
