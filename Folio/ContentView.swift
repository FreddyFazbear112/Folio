import SwiftUI

private let folioPaper = Color(red: 0.96, green: 0.94, blue: 0.89)
private let folioInk = Color(red: 0.18, green: 0.20, blue: 0.17)

struct ContentView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var showingAddBook = false
    @State private var selectedBook: Book?
    @AppStorage("folio.hasWelcomed") private var hasWelcomed = false

    var body: some View {
        Group {
            if !hasWelcomed {
                WelcomeView { withAnimation(.easeInOut(duration: 0.35)) { hasWelcomed = true } }
            } else {
                TabView {
                    libraryTab
                        .tabItem { Label("My shelf", systemImage: "books.vertical") }
                    CommunityView()
                        .tabItem { Label("Reading room", systemImage: "text.bubble") }
                    ProfileView()
                        .tabItem { Label("Me", systemImage: "person.crop.circle") }
                }
                .tint(folioInk)
            }
        }
        .sheet(isPresented: $showingAddBook) {
            AddBookView().environmentObject(library)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var libraryTab: some View {
        NavigationStack {
            ZStack {
                folioPaper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FOLIO").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(3.5)
                                Text("a life between the pages").font(.system(size: 12, design: .serif).italic()).foregroundStyle(folioInk.opacity(0.62))
                            }
                            Spacer()
                            Button { showingAddBook = true; SoundEffects.softTap() } label: {
                                Image(systemName: "plus").font(.system(size: 17, weight: .medium))
                                    .frame(width: 42, height: 42).background(folioInk).foregroundStyle(folioPaper).clipShape(Circle())
                            }
                            .accessibilityLabel("Add a book")
                        }
                        .foregroundStyle(folioInk)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("YOUR LITTLE\nCORNER OF THE\nLITERARY WORLD.")
                                .font(.system(size: 33, weight: .regular, design: .serif)).tracking(-1.1).lineSpacing(-1).foregroundStyle(folioInk)
                            Text("Keep the stories you love, and the ones you're yet to find.")
                                .font(.system(size: 14, design: .serif)).foregroundStyle(folioInk.opacity(0.68))
                        }
                        .padding(.top, 15)
                        HStack(spacing: 8) {
                            ForEach(ReadingStatus.allCases) { status in
                                NavigationLink {
                                    ShelfListView(status: status) { book in selectedBook = book }
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(status.rawValue.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1)
                                        Text("\(library.books(for: status).count)").font(.system(size: 25, design: .serif))
                                    }
                                    .foregroundStyle(folioInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(13)
                                    .background(.white.opacity(0.48))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("On your shelf").font(.system(size: 23, design: .serif)).foregroundStyle(folioInk)
                                Spacer()
                                Text("\(library.books.count) BOOKS").font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(folioInk.opacity(0.5))
                            }
                            .padding(.bottom, 17)
                            if library.books.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "books.vertical").font(.system(size: 30, weight: .ultraLight))
                                    Text("A little room for a new story.").font(.system(size: 15, design: .serif).italic())
                                    Button("Add your first book") { showingAddBook = true }
                                }
                                .foregroundStyle(folioInk.opacity(0.55)).frame(maxWidth: .infinity, minHeight: 180)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)], spacing: 22) {
                                    ForEach(library.books) { book in
                                        Button { selectedBook = book; SoundEffects.pageTurn() } label: { BookSpine(book: book) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                            Rectangle().fill(folioInk.opacity(0.65)).frame(height: 3)
                            Rectangle().fill(folioInk.opacity(0.12)).frame(height: 2)
                        }
                        HStack {
                            Text("READ SLOWLY. KEEP THE GOOD ONES.").font(.system(size: 9, weight: .medium)).tracking(1.6)
                            Spacer()
                            Image(systemName: "leaf")
                        }
                        .foregroundStyle(folioInk.opacity(0.42))
                    }
                    .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct BookSpine: View {
    let book: Book
    private let palette: [Color] = [
        Color(red: 0.43, green: 0.31, blue: 0.27), Color(red: 0.32, green: 0.40, blue: 0.35),
        Color(red: 0.69, green: 0.48, blue: 0.33), Color(red: 0.37, green: 0.39, blue: 0.51),
        Color(red: 0.62, green: 0.56, blue: 0.43), Color(red: 0.53, green: 0.34, blue: 0.36)
    ]
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(palette[book.colorIndex % palette.count].gradient)
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 2, y: 4)
                VStack(spacing: 5) {
                    Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
                    Text(book.title.uppercased()).font(.system(size: 9, weight: .semibold, design: .serif))
                        .tracking(0.7).multilineTextAlignment(.center).lineLimit(5).minimumScaleFactor(0.7)
                        .foregroundStyle(.white.opacity(0.92)).padding(.horizontal, 5)
                    Spacer(minLength: 2)
                    Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
                    Text("✳").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 10).padding(.horizontal, 4)
            }
            .frame(height: 154)
            .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.16)).frame(width: 4) }
            Text(book.author).font(.system(size: 10, design: .serif)).foregroundStyle(folioInk.opacity(0.7)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ShelfListView: View {
    @EnvironmentObject private var library: LibraryStore
    let status: ReadingStatus
    let onSelect: (Book) -> Void
    var body: some View {
        List(library.books(for: status)) { book in
            Button { onSelect(book) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.system(size: 17, design: .serif)).foregroundStyle(folioInk)
                    Text(book.author).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .scrollContentBackground(.hidden)
        .background(folioPaper)
        .navigationTitle(status.rawValue)
    }
}

private struct BookDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let book: Book

    var body: some View {
        VStack(spacing: 12) {
            Text(book.title).font(.system(size: 25, design: .serif)).multilineTextAlignment(.center)
            Text(book.author.uppercased()).font(.system(size: 10, weight: .medium)).tracking(1.4).foregroundStyle(.secondary)
            BookPreview3D(title: book.title, tint: UIColor(red: 0.43, green: 0.31, blue: 0.27, alpha: 1))
                .frame(height: 270)
            Text("Drag to turn your book around").font(.system(size: 12, design: .serif).italic()).foregroundStyle(.secondary)
            Picker("Reading status", selection: Binding(
                get: { library.books.first(where: { $0.id == book.id })?.status ?? book.status },
                set: { library.update(book, status: $0); SoundEffects.softTap() }
            )) {
                ForEach(ReadingStatus.allCases) { status in Text(status.rawValue).tag(status) }
            }
            .pickerStyle(.segmented)
            Button(role: .destructive) {
                library.remove(book)
                dismiss()
            } label: {
                Label("Remove from my shelf", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.top, 5)
        }
        .padding(22)
        .background(folioPaper.ignoresSafeArea())
    }
}
