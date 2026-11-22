import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    @State private var reveal = false
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().stroke(ink.opacity(0.12), lineWidth: 1).frame(width: 240, height: 240)
                    Image(systemName: "book.closed")
                        .font(.system(size: 78, weight: .ultraLight))
                        .rotationEffect(.degrees(reveal ? -7 : 7))
                        .offset(y: reveal ? -5 : 5)
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .light))
                        .offset(x: 90, y: -76)
                }
                .foregroundStyle(ink)
                .padding(.bottom, 42)
                Text("F O L I O")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(ink)
                Text("Make room
for a good story.")
                    .font(.system(size: 38, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ink)
                    .padding(.top, 18)
                Text("A home for your books, your thoughts,
and the people who love reading too.")
                    .font(.system(size: 14, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundStyle(ink.opacity(0.65))
                    .padding(.top, 13)
                Spacer()
                Button(action: onContinue) {
                    HStack {
                        Text("Come on in")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ink)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 28)
                Text("A QUIETER KIND OF SOCIAL READING")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(ink.opacity(0.42))
                    .padding(.top, 18)
                    .padding(.bottom, 20)
            }
            .padding(24)
            .opacity(reveal ? 1 : 0.65)
            .offset(y: reveal ? 0 : 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { reveal = true }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { reveal = false }
        }
    }
}
