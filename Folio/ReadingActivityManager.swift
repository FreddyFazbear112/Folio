import ActivityKit
import Foundation

@MainActor
final class ReadingActivityManager {
    static let shared = ReadingActivityManager()
    private var activity: Activity<FolioReadingActivityAttributes>?

    func start(bookID: String, title: String, author: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = FolioReadingActivityAttributes(bookID: bookID, startedAt: .now)
        let state = FolioReadingActivityAttributes.ContentState(
            elapsedSeconds: 0, isPaused: false, runningSince: .now, bookTitle: title, author: author
        )
        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60 * 12))
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
        }
    }

    func update(elapsed: Int, paused: Bool, title: String, author: String) async {
        guard let activity else { return }
        let state = FolioReadingActivityAttributes.ContentState(
            elapsedSeconds: max(0, elapsed), isPaused: paused, runningSince: paused ? nil : .now, bookTitle: title, author: author
        )
        await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60 * 12)))
    }

    func end(elapsed: Int, title: String, author: String) async {
        guard let activity else { return }
        let state = FolioReadingActivityAttributes.ContentState(
            elapsedSeconds: max(0, elapsed), isPaused: true, runningSince: nil, bookTitle: title, author: author
        )
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now.addingTimeInterval(8)))
        self.activity = nil
    }
}
