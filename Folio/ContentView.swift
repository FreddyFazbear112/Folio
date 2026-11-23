import SwiftUI

enum FolioPalette {
    static let bg = Color(red: 0.06, green: 0.05, blue: 0.04)
    static let card = Color(red: 0.11, green: 0.09, blue: 0.08)
    static let cardElevated = Color(red: 0.15, green: 0.12, blue: 0.10)
    static let border = Color.white.opacity(0.09)
    static let gold = Color(red: 0.85, green: 0.71, blue: 0.49)
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let muted = Color(red: 0.68, green: 0.63, blue: 0.56)
}

enum FolioTab: Hashable { case home, library, discover, stats, more }

struct ContentView: View {
    @EnvironmentObject var library: LibraryStore
    @AppStorage("folio.hasWelcomed") private var hasWelcomed = false

    @State private var tab: FolioTab = .home
    @State private var selectedBook: Book?
    @State private var readerBook: Book?
    @State private var showImport = false

    var body: some View {
        ZStack {
            FolioPalette.bg.ignoresSafeArea()
            if !hasWelcomed {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) { hasWelcomed = true }
                }
            } else {
                VStack(spacing: 0) {
                    activeTabView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    darkTabBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedBook) { book in
            BookPreview3D(book: book) { target in
                selectedBook = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    readerBook = target
                }
            }
        }
        .fullScreenCover(item: $readerBook) { book in
            if let url = library.digitalFileURL(for: book) {
                Folio3DBookReader(
                    url: url,
                    title: book.title,
                    coverURL: book.coverURL,
                    initialPage: max(1, book.currentPage ?? 1)
                ) { cur, tot in
                    library.updateReadingDetails(book, currentPage: cur, totalPages: tot, note: book.readingNote)
                }
            }
        }
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch tab {
        case .home:
            FolioHomeTab(
                onSelect: { selectedBook = $0 },
                onPlay: { readerBook = $0 },
                onSeeLibrary: { tab = .library },
                onProfile: { tab = .more }
            )
        case .library:
            FolioLibraryTab(onSelect: { selectedBook = $0 }, onImport: { showImport = true })
        case .discover:
            CommunityView()
        case .stats:
            FolioStatsTab()
        case .more:
            ProfileView()
        }
    }

    private var darkTabBar: some View {
        HStack(spacing: 0) {
            tabBtn(.home, "Home", "house.fill")
            tabBtn(.library, "Library", "books.vertical.fill")
            tabBtn(.discover, "Discover", "magnifyingglass")
            tabBtn(.stats, "Stats", "chart.bar.fill")
            tabBtn(.more, "More", "ellipsis")
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(FolioPalette.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(FolioPalette.border).frame(height: 1) }
    }

    private func tabBtn(_ target: FolioTab, _ title: String, _ icon: String) -> some View {
        let active = tab == target
        return Button { tab = target } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: active ? .semibold : .regular))
                Text(title).font(.system(size: 10, weight: active ? .semibold : .medium))
            }
            .foregroundStyle(active ? FolioPalette.gold : FolioPalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct FolioHomeTab: View {
    @EnvironmentObject var library: LibraryStore
    var onSelect: (Book) -> Void
    var onPlay: (Book) -> Void
    var onSeeLibrary: () -> Void
    var onProfile: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Folio")
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    Spacer()
                    Button(action: onProfile) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(FolioPalette.gold)
                    }
                }

                Text("Good evening,\nReader 👋")
                    .font(.system(size: 24, design: .serif))
                    .foregroundStyle(FolioPalette.cream)

                if let current = library.continueReadingBook {
                    continueCard(current)
                }

                HStack {
                    Text("Your Library").font(.system(size: 20, design: .serif)).foregroundStyle(FolioPalette.cream)
                    Spacer()
                    Button("See all >", action: onSeeLibrary).font(.caption).foregroundStyle(FolioPalette.gold)
                }

                HStack(spacing: 10) {
                    statBox("book.closed.fill", "All Books", "\(library.books.count)")
                    statBox("star.fill", "Favorites", "\(library.favoriteBooks.count)")
                    statBox("clock.arrow.circlepath", "Recently Read", "\(library.recentlyReadBooks.count)")
                }

                if !library.recentlyAddedBooks.isEmpty {
                    HStack {
                        Text("Recently Added").font(.system(size: 20, design: .serif)).foregroundStyle(FolioPalette.cream)
                        Spacer()
                        Button("See all >", action: onSeeLibrary).font(.caption).foregroundStyle(FolioPalette.gold)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(library.recentlyAddedBooks.prefix(8)) { book in
                                Button { onSelect(book) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        FolioCoverCard(book: book, width: 108, height: 158)
                                        Text(book.title).font(.caption.weight(.semibold)).foregroundStyle(FolioPalette.cream).lineLimit(1)
                                        Text(book.author).font(.caption2).foregroundStyle(FolioPalette.muted).lineLimit(1)
                                    }
                                    .frame(width: 108)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func continueCard(_ book: Book) -> some View {
        Button { onSelect(book) } label: {
            HStack(spacing: 14) {
                FolioCoverCard(book: book, width: 62, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Reading").font(.caption2.weight(.semibold)).foregroundStyle(FolioPalette.gold)
                    Text(book.title).font(.system(size: 18, weight: .semibold, design: .serif)).foregroundStyle(FolioPalette.cream).lineLimit(1)
                    Text(book.author).font(.caption).foregroundStyle(FolioPalette.muted).lineLimit(1)
                    Text(book.timeLeftLabel).font(.caption2).foregroundStyle(FolioPalette.muted)
                }
                Spacer()
                Button { library.markOpened(book); onPlay(book) } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(FolioPalette.gold, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(FolioPalette.cardElevated, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(FolioPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statBox(_ icon: String, _ title: String, _ count: String) -> some View {
        Button(action: onSeeLibrary) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).foregroundStyle(FolioPalette.gold)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(FolioPalette.cream).lineLimit(1)
                Text(count).font(.caption2).foregroundStyle(FolioPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FolioPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct FolioCoverCard: View {
    let book: Book
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let str = book.coverURL, let url = URL(string: str) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
.clipShape(RoundedRectangle(cornerRadius: 10))
.overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FolioPalette.border, lineWidth: 1))
}
private var placeholder: some View {
ZStack {
Color(red: 0.20, green: 0.15, blue: 0.11)
Text(book.title)
.font(.system(size: max(10, width * 0.13), weight: .semibold, design: .serif))
.foregroundStyle(FolioPalette.gold)
.multilineTextAlignment(.center)
.padding(6)
}
}
}
