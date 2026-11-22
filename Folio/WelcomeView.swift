import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    @State private var reveal = false
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)
    private let walnut = Color(red: 0.43, green: 0.31, blue: 0.25)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("FOLIO").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(4)
                    Spacer()
                    Text("EST. FOR READERS").font(.system(size: 8, weight: .medium)).tracking(1.8).foregroundStyle(ink.opacity(0.42))
                }
                .foregroundStyle(ink)
                .padding(.top, 16)

                Spacer(minLength: 24)
                ZStack {
                    Circle().stroke(ink.opacity(0.12), lineWidth: 1).frame(width: 270, height: 270)
                    Circle().stroke(ink.opacity(0.07), lineWidth: 1).frame(width: 222, height: 222)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [walnut, Color(red: 0.28, green: 0.22, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 118, height: 174)
                        .overlay {
                            VStack(spacing: 10) {
                                Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
                                Image(systemName: "leaf").font(.system(size: 24, weight: .ultraLight))
                                Text("FOLIO").font(.system(size: 13, weight: .medium, design: .serif)).tracking(3)
                                Spacer()
                                Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
                            }
                            .foregroundStyle(Color(red: 0.96, green: 0.91, blue: 0.82))
                            .padding(12)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 18, x: 8, y: 14)
                        .rotation3DEffect(.degrees(reveal ? -8 : 5), axis: (x: 0.3, y: 1, z: 0), perspective: 0.65)
                        .offset(x: reveal ? -4 : 5, y: reveal ? -3 : 5)
                    Image(systemName: "sparkle").font(.system(size: 19, weight: .light)).offset(x: 105, y: -96)
                    Image(systemName: "sparkle").font(.system(size: 11, weight: .light)).offset(x: -112, y: 79)
                }
                .foregroundStyle(walnut)
                .padding(.bottom, 36)

                Text("A LIFE BETWEEN\nTHE PAGES.")
                    .font(.system(size: 37, weight: .regular, design: .serif))
                    .tracking(-1.3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .foregroundStyle(ink)
                Text("Your books, your reading rituals, your own little literary corner.")
                    .font(.system(size: 14, design: .serif))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ink.opacity(0.66))
                    .frame(maxWidth: 290)
                    .padding(.top, 14)

                Spacer(minLength: 28)
                Button(action: onContinue) {
                    HStack {
                        Text("Enter Folio")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(paper)
                    .padding(.horizontal, 21)
                    .padding(.vertical, 17)
                    .background(ink)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 8)
                Text("A QUIETER KIND OF SOCIAL READING")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.7)
                    .foregroundStyle(ink.opacity(0.4))
                    .padding(.top, 17)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 28)
            .opacity(reveal ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { reveal = true }
        }
    }
}
