import Foundation

enum ReadingStatus: String, CaseIterable, Identifiable, Codable {
    case toRead = "To Read"
    case reading = "Reading"
    case finished = "Read"
    var id: String { rawValue }
}

struct Book: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var status: ReadingStatus
    var colorIndex: Int = 0
}
