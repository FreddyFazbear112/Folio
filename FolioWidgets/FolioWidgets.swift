import ActivityKit
import SwiftUI
import WidgetKit

private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)
private let muted = Color(red: 0.49, green: 0.46, blue: 0.40)

struct FolioReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FolioReadingActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(ink)
                    .frame(width: 46, height: 58)
                    .background(Color(red: 0.84, green: 0.79, blue: 0.68))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOLIO · READING SESSION")
                        .font(.system(size: 8, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(muted)
                    Text(context.state.bookTitle).font(.system(size: 16, design: .serif)).foregroundStyle(ink).lineLimit(1)
                    Text(context.state.author).font(.system(size: 11, design: .serif)).foregroundStyle(muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timer(context.state))
                        .font(.system(size: 18, design: .serif).monospacedDigit()).foregroundStyle(ink)
                    Text(context.state.isPaused ? "PAUSED" : "IN SESSION")
                        .font(.system(size: 7, weight: .semibold)).tracking(1).foregroundStyle(muted)
                }
            }
            .padding(14)
            .activityBackgroundTint(paper)
            .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.closed.fill").foregroundStyle(.brown)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.bookTitle).font(.system(size: 13, design: .serif)).lineLimit(1)
                        Text(context.state.author).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timer(context.state)).font(.system(size: 13, design: .rounded).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label(context.state.isPaused ? "Reading paused" : "A little time for a story",
                          systemImage: context.state.isPaused ? "pause.fill" : "book.pages")
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "book.closed.fill").foregroundStyle(.brown)
            } compactTrailing: {
                Text(timer(context.state)).font(.system(size: 11, design: .rounded).monospacedDigit())
            } minimal: {
                Image(systemName: "book.closed.fill").foregroundStyle(.brown)
            }
            .keylineTint(.brown)
        }
    }

    private func timer(_ state: FolioReadingActivityAttributes.ContentState) -> String {
        let value = state.elapsedSeconds
        return String(format: "%02d:%02d", value / 3600, (value / 60) % 60)
    }
}

struct FolioShelfEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let progress: Double
}

struct FolioShelfProvider: TimelineProvider {
    func placeholder(in context: Context) -> FolioShelfEntry {
        FolioShelfEntry(date: .now, title: "A book for the afternoon", author: "Your next favourite", progress: 0.35)
    }
    func getSnapshot(in context: Context, completion: @escaping (FolioShelfEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FolioShelfEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
    private func entry() -> FolioShelfEntry {
        let defaults = UserDefaults(suiteName: "group.com.folio.app")
        return FolioShelfEntry(date: .now,
            title: defaults?.string(forKey: "widget.current.title") ?? "Choose your next story",
            author: defaults?.string(forKey: "widget.current.author") ?? "Your Folio library",
            progress: defaults?.double(forKey: "widget.current.progress") ?? 0)
    }
}

struct FolioShelfWidget: Widget {
    let kind = "FolioShelfWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FolioShelfProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FOLIO").font(.system(size: 9, weight: .bold)).tracking(2)
                    Spacer()
                    Image(systemName: "books.vertical").font(.system(size: 12))
                }.foregroundStyle(muted)
                Spacer(minLength: 0)
                Text(entry.title).font(.system(size: 20, design: .serif)).foregroundStyle(ink).lineLimit(2)
                Text(entry.author).font(.system(size: 11, design: .serif)).foregroundStyle(muted).lineLimit(1)
                ProgressView(value: entry.progress).tint(Color(red: 0.48, green: 0.35, blue: 0.25))
                Text("A LIFE BETWEEN THE PAGES").font(.system(size: 7, weight: .medium)).tracking(1.1).foregroundStyle(muted)
            }
            .padding(14)
            .containerBackground(paper, for: .widget)
        }
        .configurationDisplayName("Currently reading")
        .description("A quiet little reminder of the book you're reading.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FolioWidgets: WidgetBundle {
    var body: some Widget {
        FolioReadingLiveActivity()
        FolioShelfWidget()
    }
}
