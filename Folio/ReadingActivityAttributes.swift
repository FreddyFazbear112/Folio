import ActivityKit
import Foundation

struct FolioReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isPaused: Bool
        var bookTitle: String
        var author: String
    }

    var bookID: String
    var startedAt: Date
}

