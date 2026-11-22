import Foundation

enum ReadingStatus: String, CaseIterable, Identifiable, Codable {
    case toRead = "To Read"
    case reading = "Reading"
    case finished = "Read"
    var id: String { rawValue }
}

enum BookFileFormat: String, CaseIterable, Identifiable {
    case all = "All"
    case epub = "EPUB"
    case pdf = "PDF"
    case txt = "TXT"
    var id: String { rawValue }
}

struct Book: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var status: ReadingStatus
    var colorIndex: Int = 0
    var coverURL: String? = nil
    var currentPage: Int? = nil
    var totalPages: Int? = nil
    var readingNote: String? = nil
    var isbn: String? = nil
    var ownedISBN: String? = nil
    var digitalFileName: String? = nil
    var spineColorHex: String? = nil
    var backCoverURL: String? = nil
    var isFavorite: Bool = false
    var lastOpenedAt: Date? = nil
    var addedAt: Date = Date()
    var synopsis: String? = nil
    var genre: String? = nil
    var rating: Double? = nil

    var fileFormat: BookFileFormat {
        guard let ext = digitalFileName?
            .split(separator: ".")
            .last?
            .lowercased() else {
            return .pdf
        }
        switch ext {
        case "epub": return .epub
        case "txt": return .txt
        default: return .pdf
        }
    }

    var progressFraction: Double {
        if status == .finished { return 1.0 }
        guard let current = currentPage,
              let total = totalPages,
              total > 0 else {
            return 0
        }
        return min(1.0, max(0.0, Double(current) / Double(total)))
    }

    var progressPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    var timeLeftLabel: String {
        guard let current = currentPage,
              let total = totalPages,
              total > current else {
            return status == .finished ? "Completed" : "Not Started"
        }
        let remainingPages = total - current
        let totalMinutes = max(1, Int(Double(remainingPages) * 1.4))
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(progressPercent)% • \(hours)h \(mins)m left"
        }
        return "\(progressPercent)% • \(mins)m left"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, status, colorIndex, coverURL
        case currentPage, totalPages, readingNote, isbn, ownedISBN
        case digitalFileName, spineColorHex, backCoverURL
        case isFavorite, lastOpenedAt, addedAt, synopsis, genre, rating
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        status: ReadingStatus,
        colorIndex: Int = 0,
        coverURL: String? = nil,
        currentPage: Int? = nil,
        totalPages: Int? = nil,
        readingNote: String? = nil,
        isbn: String? = nil,
        ownedISBN: String? = nil,
        digitalFileName: String? = nil,
        spineColorHex: String? = nil,
        backCoverURL: String? = nil,
        isFavorite: Bool = false,
        lastOpenedAt: Date? = nil,
        addedAt: Date = Date(),
        synopsis: String? = nil,
        genre: String? = nil,
        rating: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.colorIndex = colorIndex
        self.coverURL = coverURL
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.readingNote = readingNote
        self.isbn = isbn
        self.ownedISBN = ownedISBN
        self.digitalFileName = digitalFileName
        self.spineColorHex = spineColorHex
        self.backCoverURL = backCoverURL
        self.isFavorite = isFavorite
        self.lastOpenedAt = lastOpenedAt
        self.addedAt = addedAt
        self.synopsis = synopsis
        self.genre = genre
        self.rating = rating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        author = try c.decode(String.self, forKey: .author)
        status = try c.decode(ReadingStatus.self, forKey: .status)
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        coverURL = try c.decodeIfPresent(String.self, forKey: .coverURL)
        currentPage = try c.decodeIfPresent(Int.self, forKey: .currentPage)
        totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages)
        readingNote = try c.decodeIfPresent(String.self, forKey: .readingNote)
        isbn = try c.decodeIfPresent(String.self, forKey: .isbn)
        ownedISBN = try c.decodeIfPresent(String.self, forKey: .ownedISBN)
        digitalFileName = try c.decodeIfPresent(String.self, forKey: .digitalFileName)
        spineColorHex = try c.decodeIfPresent(String.self, forKey: .spineColorHex)
        backCoverURL = try c.decodeIfPresent(String.self, forKey: .backCoverURL)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
    }
}
