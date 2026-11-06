import CorbeilleCore
import SwiftUI

extension TrashItemKind {
    var symbol: String {
        switch self {
        case .image: "photo"
        case .video: "video"
        case .audio: "music.note"
        case .document: "doc.text"
        case .archive: "archivebox"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .app: "macwindow"
        case .folder: "folder"
        case .file: "doc"
        }
    }

    var tileColor: Color {
        switch self {
        case .image: Color(hex: 0x7C3AED)
        case .video: Color(hex: 0xE11D48)
        case .audio: Color(hex: 0x059669)
        case .document: Color(hex: 0x2563EB)
        case .archive: Color(hex: 0xF59E0B)
        case .code: Color(hex: 0x0D9488)
        case .app: Color(hex: 0x4F46E5)
        case .folder: Color(hex: 0x0284C7)
        case .file: Color(hex: 0x475569)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

struct OverlayView: View {
    let store: TrashStore

    var body: some View {
        GeometryReader { area in
            if store.isOverflowing,
                let metrics = PileLayout.metrics(
                    fillRatio: store.fillRatio, intensity: store.intensity,
                    areaWidth: area.size.width, areaHeight: area.size.height)
            {
                let kinds = store.items.isEmpty ? [TrashItemKind.file] : store.items.map(\.kind)
                ZStack(alignment: .bottom) {
                    // Warning glow, growing with how far past the threshold the Trash is.
                    EllipticalGradient(
                        colors: [Color(hex: 0xF43F5E).opacity(metrics.glowOpacity), .clear],
                        center: .bottom, startRadiusFraction: 0, endRadiusFraction: 0.7
                    )
                    .frame(width: metrics.width * 1.5, height: metrics.height * 1.2)
                    .blur(radius: 8)

                    // Grounding shadow.
                    EllipticalGradient(colors: [.black.opacity(0.28), .clear], endRadiusFraction: 0.5)
                        .frame(width: metrics.width * 1.05, height: 48)

                    Pile(metrics: metrics, kinds: kinds)
                        .frame(width: metrics.width, height: metrics.height)
                }
                .frame(width: area.size.width, height: area.size.height, alignment: .bottom)
                .animation(.easeInOut(duration: 0.6), value: metrics)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Pile: View {
    let metrics: PileMetrics
    let kinds: [TrashItemKind]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<metrics.pieceCount, id: \.self) { index in
                    let piece = PileLayout.pieces[index]
                    let center = piece.center(pileWidth: metrics.width, pileHeight: metrics.height)
                    PieceView(piece: piece, kind: kinds[index % kinds.count])
                        .position(x: center.x, y: metrics.height - center.y)
                        .offset(y: Self.bob(piece, at: time))
                        .zIndex(1 - piece.verticalPosition)
                }
            }
            .frame(width: metrics.width, height: metrics.height)
        }
    }

    /// Gentle 3 pt bobbing, each piece on its own rhythm.
    private static func bob(_ piece: PiecePlacement, at time: Double) -> CGFloat {
        let phase = (time - piece.bobDelay) / piece.bobDuration * 2 * .pi
        return -3 * (1 - cos(phase)) / 2
    }
}

private struct PieceView: View {
    let piece: PiecePlacement
    let kind: TrashItemKind

    var body: some View {
        let size = piece.size
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(kind.tileColor)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(.black.opacity(0.15), lineWidth: 1)
            }
            .overlay {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(piece.rotationDegrees))
            .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
    }
}
