import SwiftUI

private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)

struct ContentView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedShelf: ReadingStatus = .toRead
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        welcomeNote
                        shelfPicker
                        bookshelf
                        footerNote
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 36)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
                    .environmentObject(library)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(ink)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOLIO")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(3.5)
                Text("a life between the pages")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(ink.opacity(0.62))
            }
            Spacer()
            Button { showingAddBook = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(ink)
                    .foregroundStyle(paper)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add a book")
        }
        .foregroundStyle(ink)
    }

    private var welcomeNote: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("YOUR LITTLE
CORNER OF THE
LITERARY WORLD.")
                .font(.system(size: 33, weight: .regular, design: .serif))
                .tracking(-1.1)
                .lineSpacing(-1)
                .foregroundStyle(ink)
            Text("Keep the stories you love, and the ones you're yet to find.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(ink.opacity(0.68))
        }
        .padding(.top, 18)
    }

    private var shelfPicker: some View {
        HStack(spacing: 8) {
            ForEach(ReadingStatus.allCases) { status in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { selectedShelf = status }
                } label: {
                    Text(status.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(selectedShelf == status ? ink : Color.clear)
                        .foregroundStyle(selectedShelf == status ? paper : ink.opacity(0.62))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ink.opacity(selectedShelf == status ? 0 : 0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var bookshelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedShelf.rawValue)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                Spacer()
                Text("\(library.books(for: selectedShelf).count) BOOKS")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(ink.opacity(0.5))
            }
            .padding(.bottom, 17)

            if library.books(for: selectedShelf).isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 30, weight: .ultraLight))
                    Text("A little room for a new story.")
                        .font(.system(size: 15, design: .serif).italic())
                    Button("Add your first book") { showingAddBook = true }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.top, 4)
                }
                .foregroundStyle(ink.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 210)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)], alignment: .center, spacing: 23) {
                    ForEach(library.books(for: selectedShelf)) { book in
                        BookSpine(book: book)
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 14)
            }

            Rectangle()
                .fill(ink.opacity(0.65))
                .frame(height: 3)
            Rectangle()
                .fill(ink.opacity(0.12))
                .frame(height: 2)
        }
    }

    private var footerNote: some View {
        HStack {
            Text("READ SLOWLY. KEEP THE GOOD ONES.")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.6)
            Spacer()
            Image(systemName: "leaf")
        }
        .foregroundStyle(ink.opacity(0.42))
        .padding(.top, 6)
    }
}

private struct BookSpine: View {
    let book: Book
    private let palette: [Color] = [
        Color(red: 0.43, green: 0.31, blue: 0.27),
        Color(red: 0.32, green: 0.40, blue: 0.35),
        Color(red: 0.69, green: 0.48, blue: 0.33),
        Color(red: 0.37, green: 0.39, blue: 0.51),
        Color(red: 0.62, green: 0.56, blue: 0.43),
        Color(red: 0.53, green: 0.34, blue: 0.36)
    ]

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette[book.colorIndex % palette.count].gradient)
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 2, y: 4)
                VStack(spacing: 5) {
                    Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
                    Text(book.title.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .serif))
                        .tracking(0.7)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 5)
                    Spacer(minLength: 2)
                    Rectangle().fill(.white.opacity(0.42)).frame(height: 1)
                    Text("✳")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .frame(height: 154)
            .overlay(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.16)).frame(width: 4)
            }
            Text(book.author)
                .font(.system(size: 10, design: .serif))
                .foregroundStyle(ink.opacity(0.7))
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
