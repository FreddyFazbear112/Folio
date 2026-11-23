import SwiftUI
import UniformTypeIdentifiers

struct FolioLibraryTab: View {
    @EnvironmentObject var library: LibraryStore
    var onSelect: (Book) -> Void
    var onImport: () -> Void

    @State private var query = ""
    @State private var format: BookFileFormat = .all
    @State private var showImportSheet = false

    private var filtered: [Book] {
        library.books.filter { book in
            if format != .all && book.fileFormat != format { return false }
            if !query.isEmpty {
                let q = query.lowercased()
                return book.title.lowercased().contains(q)
                    || book.author.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Library")
                    .font(.system(size: 34, design: .serif))
                    .foregroundStyle(FolioPalette.cream)
                Spacer()
                Button {
                    showImportSheet = true
                    onImport()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FolioPalette.gold)
                        .frame(width: 38, height: 38)
                        .background(FolioPalette.cardElevated, in: Circle())
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FolioPalette.muted)
                TextField("Search your library...", text: $query)
                    .foregroundStyle(FolioPalette.cream)
            }
            .padding(11)
            .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FolioPalette.border, lineWidth: 1))

            HStack(spacing: 8) {
                ForEach(BookFileFormat.allCases) { item in
                    let active = format == item
                    Button { format = item } label: {
                        Text(item.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(active ? .black : FolioPalette.cream)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(active ? FolioPalette.gold : FolioPalette.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(FolioPalette.border, lineWidth: active ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { book in
                        Button { onSelect(book) } label: {
                            HStack(spacing: 14) {
                                FolioCoverCard(book: book, width: 54, height: 80)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.system(size: 17, weight: .semibold, design: .serif))
                                        .foregroundStyle(FolioPalette.cream)
                                        .lineLimit(1)
                                    Text(book.author)
                                        .font(.caption)
                                        .foregroundStyle(FolioPalette.muted)
                                        .lineLimit(1)
                                    Text(book.timeLeftLabel)
                                        .font(.caption2)
                                        .foregroundStyle(FolioPalette.gold)
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        library.toggleFavorite(book)
                                    } label: {
                                        Label(
                                            book.isFavorite ? "Remove Favorite" : "Add to Favorites",
                                            systemImage: book.isFavorite ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button(role: .destructive) {
                                        library.remove(book)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(FolioPalette.muted)
                                        .padding(8)
                                }
                            }
                            .padding(10)
                            .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FolioPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .sheet(isPresented: $showImportSheet) {
            FolioImportModal()
        }
    }
}

struct FolioStatsTab: View {
    @EnvironmentObject var library: LibraryStore

    private var pagesRead: Int {
        library.books.reduce(0) { $0 + ($1.currentPage ?? 0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stats")
                    .font(.system(size: 34, design: .serif))
                    .foregroundStyle(FolioPalette.cream)

                HStack(spacing: 12) {
                    metricCard("\(library.books.count)", "Books")
                    metricCard("\(library.books(for: .finished).count)", "Finished")
                    metricCard("\(pagesRead)", "Pages Read")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
    }

    private func metricCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(FolioPalette.gold)
            Text(label)
                .font(.caption)
                .foregroundStyle(FolioPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FolioPalette.border, lineWidth: 1))
    }
}

struct FolioImportModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var library: LibraryStore
    @State private var showPicker = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            FolioPalette.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(FolioPalette.cream)
                            .frame(width: 36, height: 36)
                            .background(FolioPalette.cardElevated, in: Circle())
                    }
                    Spacer()
                    Text("Import Books")
                        .font(.system(size: 20, design: .serif))
                        .foregroundStyle(FolioPalette.cream)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.top, 12)

                Button { showPicker = true } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(FolioPalette.gold)
                        Text("Tap to Import")
                            .font(.headline)
                            .foregroundStyle(FolioPalette.cream)
                        Text("Supports EPUB, PDF, TXT,\nand more...")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(FolioPalette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 185)
                    .background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(FolioPalette.gold.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6]))
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Or choose a source:")
                        .font(.subheadline)
                        .foregroundStyle(FolioPalette.muted)

                    sourceRow("folder.fill", .blue, "Files")
                    sourceRow("icloud.fill", .cyan, "iCloud Drive")
                    sourceRow("square.grid.2x2.fill", FolioPalette.gold, "Other Apps")
                }

                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }

                Spacer()

Text("Imported books will be stored\nin your Folio library.")
.font(.caption)
.multilineTextAlignment(.center)
.foregroundStyle(FolioPalette.muted)
.padding(.bottom, 16)
}
.padding(.horizontal, 20)
}
.fileImporter(
isPresented: $showPicker,
allowedContentTypes: [.pdf, .epub, .plainText],
allowsMultipleSelection: false
) { result in
importFile(result)
}
}
private func sourceRow(_ icon: String, _ color: Color, _ title: String) -> some View {
Button { showPicker = true } label: {
HStack(spacing: 14) {
Image(systemName: icon).foregroundStyle(color).frame(width: 26)
Text(title).font(.subheadline.weight(.medium)).foregroundStyle(FolioPalette.cream)
Spacer()
Image(systemName: "chevron.right").font(.caption).foregroundStyle(FolioPalette.muted)
}
.padding(14)
.background(FolioPalette.card, in: RoundedRectangle(cornerRadius: 14))
.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FolioPalette.border, lineWidth: 1))
}
.buttonStyle(.plain)
}
private func importFile(_ result: Result<[URL], Error>) {
switch result {
case .failure(let err):
errorText = err.localizedDescription
case .success(let urls):
guard let src = urls.first else { return }
let scoped = src.startAccessingSecurityScopedResource()
defer { if scoped { src.stopAccessingSecurityScopedResource() } }
do {
let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let name = "(UUID().uuidString)-(src.lastPathComponent)"
let dst = docs.appendingPathComponent(name)
try FileManager.default.copyItem(at: src, to: dst)
let cleanTitle = src.deletingPathExtension().lastPathComponent
.replacingOccurrences(of: "_", with: " ")
if let id = library.add(title: cleanTitle, author: "Imported Edition", status: .reading),
let created = library.books.first(where: { $0.id == id }) {
library.attachDigitalCopy(created, fileName: name)
}
dismiss()
} catch {
errorText = error.localizedDescription
}
}
}
}
struct AddBookView: View {
var body: some View { FolioImportModal() }
}
