import SwiftUI

/// A short branded entrance shown on every fresh app launch.
struct FolioLaunchView: View {
    let onFinished: () -> Void

    @State private var revealLogo = false
    @State private var orbit = false
    @State private var bookGlow = false

    private let cream = Color(red: 0.96, green: 0.91, blue: 1.0)
    private let lilac = Color(red: 0.77, green: 0.62, blue: 0.98)
    private let violet = Color(red: 0.31, green: 0.19, blue: 0.47)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.018, blue: 0.055),
                         Color(red: 0.105, green: 0.055, blue: 0.16),
                         Color(red: 0.055, green: 0.025, blue: 0.085)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            RadialGradient(colors: [violet.opacity(0.58), .clear],
                           center: .center, startRadius: 8, endRadius: 330)
                .ignoresSafeArea()

            LaunchStarField().opacity(0.82).ignoresSafeArea()

            Circle().stroke(lilac.opacity(0.13), lineWidth: 0.8)
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(orbit ? 360 : 0))
            Circle().stroke(cream.opacity(0.08), style: StrokeStyle(lineWidth: 0.8, dash: [2, 9]))
                .frame(width: 224, height: 224)
                .rotationEffect(.degrees(orbit ? -180 : 0))

            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(lilac.opacity(bookGlow ? 0.15 : 0.06))
                        .frame(width: 176, height: 176).blur(radius: 30)
                    Image(systemName: "book.pages")
                        .font(.system(size: 76, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LinearGradient(colors: [cream, lilac],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: lilac.opacity(bookGlow ? 0.75 : 0.25), radius: bookGlow ? 34 : 13)
                        .scaleEffect(bookGlow ? 1.035 : 0.96)
                    Image(systemName: "sparkle").font(.system(size: 17, weight: .light))
                        .foregroundStyle(cream).offset(x: 75, y: -62)
                    Image(systemName: "sparkle").font(.system(size: 11, weight: .light))
                        .foregroundStyle(lilac).offset(x: -78, y: 49)
                }
                .frame(height: 190)

                Text("Folio")
                    .font(.system(size: 43, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(cream)
                    .blur(radius: revealLogo ? 0 : 13)
                    .opacity(revealLogo ? 1 : 0.04)
                    .scaleEffect(revealLogo ? 1 : 0.94)

                Text("A QUIETER PLACE TO READ")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(3.1)
                    .foregroundStyle(lilac.opacity(0.82))
                    .opacity(revealLogo ? 1 : 0)
                    .offset(y: revealLogo ? 0 : 7)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { orbit = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bookGlow = true }
            withAnimation(.easeOut(duration: 1.05).delay(0.7)) { revealLogo = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) { onFinished() }
        }
    }
}

private struct LaunchStarField: View {
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.08,0.12,2,0.45),(0.19,0.28,1.5,0.55),(0.82,0.14,2,0.55),(0.91,0.31,1,0.4),
        (0.12,0.58,1,0.4),(0.29,0.78,2,0.35),(0.74,0.68,1.5,0.5),(0.88,0.84,2,0.45),
        (0.53,0.09,1,0.5),(0.63,0.91,1.5,0.35),(0.42,0.22,1,0.4),(0.06,0.9,1,0.3),
        (0.95,0.55,1.5,0.42),(0.34,0.48,1,0.35),(0.68,0.39,1,0.4),(0.49,0.73,1.5,0.3)
    ]
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for (x, y, radius, alpha) in stars {
                    let rect = CGRect(x: x * size.width, y: y * size.height,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
                for (x, y) in [(0.22,0.43),(0.79,0.48),(0.58,0.18)] {
                    let cx = x * size.width, cy = y * size.height
                    var path = Path()
                    path.move(to: CGPoint(x: cx - 4, y: cy)); path.addLine(to: CGPoint(x: cx + 4, y: cy))
                    path.move(to: CGPoint(x: cx, y: cy - 4)); path.addLine(to: CGPoint(x: cx, y: cy + 4))
                    context.stroke(path, with: .color(.white.opacity(0.28)), lineWidth: 0.6)
                }
            }
        }
    }
}
