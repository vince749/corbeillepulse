import CorbeilleCore
import SwiftUI

/// What the full window and the menu bar popover both show: the fill circle and its figures.
extension TrashStore {
    var gaugeColor: Color {
        if fillRatio >= 1 { return Color(hex: 0xEF4444) }
        if fillRatio >= 0.75 { return Color(hex: 0xF59E0B) }
        return Color(hex: 0x22C55E)
    }

    var statusLabel: String {
        if snapshot == nil { return String(localized: "Lecture de la corbeille…") }
        if totalBytes <= 0 { return String(localized: "Corbeille vide") }
        if fillRatio >= 1 { return String(localized: "Débordement !") }
        if fillRatio >= 0.75 { return String(localized: "Presque pleine") }
        return String(localized: "En remplissage")
    }

    var overflowPercent: Int {
        fillRatio > 1 ? Int(((fillRatio - 1) * 100).rounded()) : 0
    }

    /// The threshold slider works on a logarithmic position, not on bytes.
    var sliderPosition: Double {
        get { Threshold.sliderPosition(forBytes: thresholdBytes) }
        set { thresholdBytes = Threshold.bytes(forSliderPosition: newValue) }
    }
}

struct GaugeView: View {
    let store: TrashStore
    var diameter: CGFloat = 166
    var lineWidth: CGFloat = 14

    private var compact: Bool { diameter < 140 }

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            ZStack {
                Circle().stroke(.gray.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(store.fillRatio, 1))
                    .stroke(store.gaugeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: store.fillRatio)
                VStack(spacing: compact ? 2 : 4) {
                    Image(systemName: "trash")
                        .font(compact ? .body : .title2)
                        .foregroundStyle(store.gaugeColor)
                    Text(formatBytes(store.totalBytes))
                        .font(.system(size: compact ? 19 : 26, weight: .bold))
                        .monospacedDigit()
                    Text("sur \(formatBytes(store.thresholdBytes))")
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: diameter, height: diameter)
            .padding(lineWidth / 2)

            VStack(spacing: 2) {
                Text(store.statusLabel)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(store.gaugeColor)
                if store.overflowPercent > 0 {
                    Text("\(store.overflowPercent) % au-dessus du seuil")
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatsRow: View {
    let store: TrashStore
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            stat("Taille", formatBytes(store.totalBytes))
            Divider()
            stat("Éléments", String(store.itemCount))
            Divider()
            stat("Seuil", formatBytes(store.thresholdBytes))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(compact ? .body.weight(.semibold) : .title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(compact ? .caption : .callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
