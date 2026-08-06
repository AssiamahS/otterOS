import SwiftUI

/// Lightweight confetti burst — pure SwiftUI, no dependencies. Fired when the
/// last mission of the day is crossed off or the 10k step goal lands.
struct ConfettiView: View {
    @Binding var trigger: Bool
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let spin: Double
        let color: Color
        let size: CGFloat
    }

    private static let palette: [Color] = [.orange, .yellow, .pink, .teal, .purple, .green]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPiece(piece: piece, width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, firing in
            guard firing else { return }
            pieces = (0..<60).map { i in
                Piece(
                    x: CGFloat.random(in: 0...1),
                    delay: Double(i) * 0.015,
                    spin: Double.random(in: -720...720),
                    color: Self.palette[i % Self.palette.count],
                    size: CGFloat.random(in: 6...11)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                pieces = []
                trigger = false
            }
        }
    }
}

private struct ConfettiPiece: View {
    let piece: ConfettiView.Piece
    let width: CGFloat
    let height: CGFloat
    @State private var falling = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.6)
            .rotationEffect(.degrees(falling ? piece.spin : 0))
            .position(x: piece.x * width,
                      y: falling ? height + 40 : -30)
            .opacity(falling ? 0.9 : 1)
            .animation(.easeIn(duration: 2.2).delay(piece.delay), value: falling)
            .onAppear { falling = true }
    }
}
