import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void

    @State private var phase: Phase = .splash
    @State private var page = 0
    @State private var glow = false

    private enum Phase { case splash, tutorial }

    private let ink = Color(red: 0.055, green: 0.045, blue: 0.039)
    private let panel = Color(red: 0.13, green: 0.105, blue: 0.085)
    private let cream = Color(red: 0.95, green: 0.90, blue: 0.80)
    private let gold = Color(red: 0.83, green: 0.62, blue: 0.37)

    private let slides: [(eyebrow: String, title: String, subtitle: String, symbol: String)] = [
        ("A WORLD OF YOUR OWN", "Welcome to Folio", "Your personal reading companion. A quiet place for the stories you love.", "sparkles"),
        ("EVERY STORY, ONE HOME", "Your Library", "Bring your books together, organize your shelves, and keep your reading life close.", "books.vertical.fill"),
        ("TURN THE NEXT PAGE", "A more immersive experience", "Explore lifelike 3D books, open your reading copy, and make every page feel special.", "book.pages.fill")
    ]

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            LibraryBackdrop()
                .ignoresSafeArea()
                .opacity(phase == .splash ? 0.48 : 0.13)
            RadialGradient(colors: [Color(red: 0.31, green: 0.19, blue: 0.11).opacity(0.72), ink.opacity(0)], center: .top, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()

            if phase == .splash {
                splash
                    .transition(.opacity)
            } else {
                tutorial
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.65)) { phase = .tutorial }
            }
        }
    }

    private var splash: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(gold.opacity(0.18), lineWidth: 1).frame(width: 270, height: 270)
                Circle().stroke(gold.opacity(0.10), lineWidth: 1).frame(width: 218, height: 218)
                Image(systemName: "book.fill")
                    .font(.system(size: 78, weight: .ultraLight))
                    .foregroundStyle(LinearGradient(colors: [cream, gold], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: gold.opacity(0.45), radius: glow ? 32 : 14)
                    .rotation3DEffect(.degrees(glow ? -7 : 5), axis: (x: 0.2, y: 1, z: 0))
                Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(gold).offset(x: 104, y: -88)
                Image(systemName: "sparkle").font(.system(size: 12)).foregroundStyle(cream.opacity(0.7)).offset(x: -112, y: 74)
            }
            Spacer().frame(height: 34)
            Text("Folio")
                .font(.system(size: 58, weight: .regular, design: .serif))
                .tracking(-1.5).foregroundStyle(cream)
            Text("READ. DISCOVER. BELONG.")
                .font(.system(size: 9, weight: .medium)).tracking(3.2)
                .foregroundStyle(gold).padding(.top, 10)
            Spacer()
            ProgressView().tint(gold).frame(width: 110)
            Text("Preparing your library…")
                .font(.system(size: 11, design: .serif)).foregroundStyle(cream.opacity(0.55))
                .padding(.top, 12).padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
    }

    private var tutorial: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FOLIO").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundStyle(gold)
                Spacer()
                Button("Skip") { onContinue() }
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(cream.opacity(0.78))
            }
            .padding(.horizontal, 26).padding(.top, 18)

            Spacer(minLength: 18)

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [panel.opacity(0.85), Color(red: 0.08, green: 0.065, blue: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(gold.opacity(0.20), lineWidth: 1))
                slideArtwork
                    .padding(20)
            }
            .frame(height: 350)
            .padding(.horizontal, 25)

            Text(slides[page].eyebrow)
                .font(.system(size: 9, weight: .semibold)).tracking(2.4)
                .foregroundStyle(gold).padding(.top, 34)
            Text(slides[page].title)
                .font(.system(size: 31, weight: .regular, design: .serif))
                .multilineTextAlignment(.center).foregroundStyle(cream)
                .padding(.top, 10).padding(.horizontal, 30)
            Text(slides[page].subtitle)
                .font(.system(size: 15, design: .serif)).lineSpacing(5)
                .multilineTextAlignment(.center).foregroundStyle(cream.opacity(0.66))
                .frame(maxWidth: 300).padding(.top, 12)

            Spacer(minLength: 24)

            HStack(spacing: 9) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Capsule().fill(index == page ? gold : cream.opacity(0.22))
                        .frame(width: index == page ? 25 : 6, height: 6)
                }
            }
            .padding(.bottom, 22)

            Button {
                if page < slides.count - 1 {
                    withAnimation(.easeInOut(duration: 0.28)) { page += 1 }
                } else {
                    onContinue()
                }
            } label: {
                HStack {
                    Spacer()
                    Text(page == slides.count - 1 ? "Get Started" : "Continue")
                    Spacer()
                    Image(systemName: page == slides.count - 1 ? "arrow.right" : "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, 20).padding(.vertical, 17)
                .background(LinearGradient(colors: [Color(red: 0.91, green: 0.70, blue: 0.45), gold], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 26).padding(.bottom, 22)
        }
    }

    @ViewBuilder
    private var slideArtwork: some View {
        switch page {
        case 0:
            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle().fill(gold.opacity(0.09)).frame(width: 210, height: 210)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 108, weight: .ultraLight))
                        .foregroundStyle(LinearGradient(colors: [cream, gold], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .rotation3DEffect(.degrees(-16), axis: (x: 0.2, y: 1, z: 0.1))
                        .shadow(color: gold.opacity(0.24), radius: 24, y: 12)
                    Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(gold).offset(x: 88, y: -74)
                }
                Text("A little literary corner, made for you.")
                    .font(.system(size: 14, design: .serif)).italic().foregroundStyle(cream.opacity(0.65))
                Spacer()
            }
        case 1:
            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(gold)
                    Text("Search your library").foregroundStyle(cream.opacity(0.5))
                    Spacer()
                    Image(systemName: "slider.horizontal.3").foregroundStyle(gold)
                }
                .font(.system(size: 12, design: .serif))
                .padding(13).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                HStack(alignment: .bottom, spacing: 12) {
                    miniBook("DUNE", color: Color(red: 0.25, green: 0.38, blue: 0.43), height: 178)
                    miniBook("1984", color: Color(red: 0.46, green: 0.16, blue: 0.14), height: 154)
                    miniBook("THE HOBBIT", color: Color(red: 0.25, green: 0.34, blue: 0.22), height: 166)
                }
                HStack {
                    Label("All Books", systemImage: "books.vertical")
                    Spacer()
                    Label("Favorites", systemImage: "star")
                }
                .font(.system(size: 11, design: .serif)).foregroundStyle(cream.opacity(0.78))
                .padding(13).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 20)
        default:
            VStack(spacing: 12) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.31, green: 0.20, blue: 0.14))
                        .frame(width: 178, height: 238)
                        .overlay {
                            VStack(spacing: 14) {
                                Rectangle().fill(gold.opacity(0.6)).frame(height: 1)
                                Image(systemName: "book.closed").font(.system(size: 35, weight: .ultraLight))
                                Text("FOLIO EDITION").font(.system(size: 14, design: .serif)).tracking(2)
                                Spacer()
                                Text("A STORY TO KEEP").font(.system(size: 8, weight: .medium)).tracking(2)
                                Rectangle().fill(gold.opacity(0.6)).frame(height: 1)
                            }.foregroundStyle(cream).padding(16)
                        }
                        .rotation3DEffect(.degrees(-19), axis: (x: 0.2, y: 1, z: 0.1))
                        .shadow(color: .black.opacity(0.5), radius: 22, x: 12, y: 18)
                    Image(systemName: "hand.draw").font(.system(size: 22)).foregroundStyle(gold).offset(x: 104, y: 90)
                }
                Text("A real book object, ready to open.")
                    .font(.system(size: 13, design: .serif)).italic().foregroundStyle(cream.opacity(0.66))
                Spacer()
            }
        }
    }

    private func miniBook(_ title: String, color: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(maxWidth: .infinity).frame(height: height)
            .overlay {
                VStack(spacing: 8) {
                    Rectangle().fill(cream.opacity(0.45)).frame(height: 1)
                    Text(title).font(.system(size: 15, design: .serif)).multilineTextAlignment(.center)
                    Spacer()
                    Text("FOLIO").font(.system(size: 7, weight: .medium)).tracking(2)
                    Rectangle().fill(cream.opacity(0.45)).frame(height: 1)
                }.foregroundStyle(cream).padding(9)
            }
            .shadow(color: .black.opacity(0.28), radius: 8, x: 3, y: 5)
    }
}


private struct LibraryBackdrop: View {
    private let shelfColor = Color(red: 0.24, green: 0.14, blue: 0.085)
    private let bookColors: [Color] = [
        Color(red: 0.28, green: 0.12, blue: 0.09),
        Color(red: 0.18, green: 0.22, blue: 0.18),
        Color(red: 0.35, green: 0.24, blue: 0.14),
        Color(red: 0.12, green: 0.16, blue: 0.19),
        Color(red: 0.30, green: 0.18, blue: 0.16)
    ]

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(7.0, (geometry.size.width / 6.0 - 18.0) / 5.0)
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.105, blue: 0.07), Color(red: 0.035, green: 0.027, blue: 0.022)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                HStack(spacing: 0) {
                    shelfColumn(index: 0, bookWidth: columnWidth)
                    shelfColumn(index: 1, bookWidth: columnWidth)
                    shelfColumn(index: 2, bookWidth: columnWidth)
                    shelfColumn(index: 3, bookWidth: columnWidth)
                    shelfColumn(index: 4, bookWidth: columnWidth)
                    shelfColumn(index: 5, bookWidth: columnWidth)
                }
                LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private func shelfColumn(index: Int, bookWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            shelfRow(column: index, shelf: 0, bookWidth: bookWidth)
            shelfRow(column: index, shelf: 1, bookWidth: bookWidth)
            shelfRow(column: index, shelf: 2, bookWidth: bookWidth)
            shelfRow(column: index, shelf: 3, bookWidth: bookWidth)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity)
    }

    private func shelfRow(column: Int, shelf: Int, bookWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 3) {
                shelfBook(column: column, shelf: shelf, book: 0, width: bookWidth)
                shelfBook(column: column, shelf: shelf, book: 1, width: bookWidth)
                shelfBook(column: column, shelf: shelf, book: 2, width: bookWidth)
                shelfBook(column: column, shelf: shelf, book: 3, width: bookWidth)
                shelfBook(column: column, shelf: shelf, book: 4, width: bookWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            Rectangle().fill(shelfColor).frame(height: 7)
        }
    }

    private func shelfBook(column: Int, shelf: Int, book: Int, width: CGFloat) -> some View {
        let colorIndex = (column + shelf + book) % bookColors.count
        let bookHeight = CGFloat(28 + ((column * 13 + shelf * 7 + book * 9) % 42))
        return RoundedRectangle(cornerRadius: 2)
            .fill(bookColors[colorIndex].opacity(0.82))
            .frame(width: width, height: bookHeight)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
            }
    }
}
