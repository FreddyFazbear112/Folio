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
    enum CatalogueError: LocalizedError {
        case invalidISBN
        var errorDescription: String? { "Enter a valid 10- or 13-digit ISBN." }
    }

    static func isValidISBN(_ value: String) -> Bool {
        let isbn = value.uppercased().filter { $0.isNumber || $0 == "X" }
        if isbn.count == 10 {
            let chars = Array(isbn)
            let digits = chars.enumerated().map { index, char -> Int? in
                if char == "X" { return index == 9 ? 10 : nil }
                return char.wholeNumberValue
            }
            guard digits.allSatisfy({ $0 != nil }) else { return false }
            return zip(digits.compactMap { $0 }, stride(from: 10, through: 1, by: -1)).reduce(0) { $0 + $1.0 * $1.1 } % 11 == 0
        }
        if isbn.count == 13 {
            let digits = isbn.compactMap(\.wholeNumberValue)
            guard digits.count == 13 else { return false }
            let sum = digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
            return sum.isMultiple(of: 10)
        }
        return false
    }
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
        async let libraryTask = try? searchOpenLibrary(clean)
        async let publicDomainTask = try? searchGutendex(clean)
        let (libraryResult, publicResult) = await (libraryTask, publicDomainTask)
        guard libraryResult != nil || publicResult != nil else { throw URLError(.cannotConnectToHost) }
        let libraryBooks = libraryResult ?? []
        let publicBooks = publicResult ?? []
        var results = publicBooks
        for item in libraryBooks {
            if !results.contains(where: { $0.title.localizedCaseInsensitiveCompare(item.title) == .orderedSame && $0.author.localizedCaseInsensitiveCompare(item.author) == .orderedSame }) {
                results.append(item)
            }
        }
        return Array(results.prefix(24))
    }

    func lookup(isbn: String) async throws -> CatalogueBook? {
        let raw = isbn.uppercased().filter { $0.isNumber || $0 == "X" }
        let clean = raw.filter(\.isNumber)
        guard Self.isValidISBN(raw) else { throw CatalogueError.invalidISBN }
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [URLQueryItem(name: "isbn", value: raw), URLQueryItem(name: "limit", value: "1")]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
        guard let doc = response.docs.first, let title = doc.title else { return nil }
        let author = doc.author_name?.first ?? "Unknown author"
        let cover = doc.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-L.jpg" }
        // ISBN identifies the print edition; independently check whether the same
        // work also exists as a lawful public-domain download.
        let publicEditions = (try? await searchGutendex(title)) ?? []
        if let publicEdition = publicEditions.first(where: {
            $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
        }) {
            return CatalogueBook(id: publicEdition.id, title: title, author: author, coverURL: cover ?? publicEdition.coverURL,
                isbn: doc.isbn?.first ?? clean, publicationYear: doc.first_publish_year,
                downloadableURL: publicEdition.downloadableURL, format: publicEdition.format,
                sourceLabel: publicEdition.sourceLabel)
        }
        return CatalogueBook(id: doc.key ?? clean, title: title, author: author, coverURL: cover,
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
            let cover = item.formats["image/jpeg"]
            guard let link = epub ?? pdf, let downloadURL = URL(string: link) else { return nil }
            return CatalogueBook(id: "gutenberg-\(item.id)", title: item.title, author: item.authors.first?.name ?? "Unknown author",
                coverURL: cover, isbn: nil, publicationYear: nil, downloadableURL: downloadURL,
                format: epub == nil ? "PDF" : "EPUB", sourceLabel: "Project Gutenberg · Public domain")
        }
    }
}
