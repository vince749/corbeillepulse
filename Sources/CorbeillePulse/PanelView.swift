import AppKit
import CorbeilleCore
import SwiftUI

struct PanelView: View {
    @Bindable var store: TrashStore
    let onEmpty: () -> Void

    private var gaugeColor: Color {
        if store.fillRatio >= 1 { return Color(hex: 0xEF4444) }
        if store.fillRatio >= 0.75 { return Color(hex: 0xF59E0B) }
        return Color(hex: 0x22C55E)
    }

    private var statusLabel: String {
        if store.totalBytes <= 0 { return "Corbeille vide" }
        if store.fillRatio >= 1 { return "Débordement !" }
        if store.fillRatio >= 0.75 { return "Presque pleine" }
        return "En remplissage"
    }

    private var overflowPercent: Int {
        store.fillRatio > 1 ? Int(((store.fillRatio - 1) * 100).rounded()) : 0
    }

    private var sliderPosition: Binding<Double> {
        Binding(
            get: { Threshold.sliderPosition(forBytes: store.thresholdBytes) },
            set: { store.thresholdBytes = Threshold.bytes(forSliderPosition: $0) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if store.accessBlocked { accessBanner }
                gauge
                stats
                Button(role: .destructive, action: onEmpty) {
                    Label(store.isEmptying ? "Vidage…" : "Vider la corbeille", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(store.totalBytes <= 0 || store.isEmptying)
                Divider()
                thresholdSection
                Divider()
                intensitySection
                Divider()
                contentsSection
            }
            .padding(20)
        }
        .frame(minWidth: 390, minHeight: 520)
    }

    private var accessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accès à la corbeille requis", systemImage: "exclamationmark.shield")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("macOS protège la corbeille. Autorise CorbeillePulse à contrôler le Finder dans Réglages Système › Confidentialité et sécurité › Automatisation.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les réglages") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.opacity(0.4)))
    }

    private var gauge: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.gray.opacity(0.2), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(store.fillRatio, 1))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: store.fillRatio)
                VStack(spacing: 4) {
                    Image(systemName: "trash").font(.title2).foregroundStyle(gaugeColor)
                    Text(formatBytes(store.totalBytes))
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                    Text("sur \(formatBytes(store.thresholdBytes))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 166, height: 166)
            .padding(7)

            VStack(spacing: 2) {
                Text(statusLabel).font(.headline).foregroundStyle(gaugeColor)
                if overflowPercent > 0 {
                    Text("\(overflowPercent) % au-dessus du seuil")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat("Taille", formatBytes(store.totalBytes))
            Divider()
            stat("Éléments", String(store.itemCount))
            Divider()
            stat("Seuil", formatBytes(store.thresholdBytes))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Seuil de débordement").font(.headline)
                Spacer()
                Text(formatBytes(store.thresholdBytes))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: sliderPosition, in: 0...Threshold.sliderMax)
            Text("En dessous de ce seuil, rien ne s'affiche. Au-delà, la corbeille déborde par-dessus le Dock.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intensité du débordement").font(.headline)
            Picker("Intensité du débordement", selection: $store.intensity) {
                Text("Léger").tag(Intensity.light)
                Text("Progressif").tag(Intensity.progressive)
                Text("Dramatique").tag(Intensity.dramatic)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hasUnknownSize(_ item: TrashItem) -> Bool {
        item.bytes == 0 && (item.kind == .folder || item.kind == .app)
    }

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contenu").font(.headline)
            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("La corbeille est vide.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(store.items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.kind.symbol)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(hasUnknownSize(item) ? "—" : formatBytes(item.bytes))
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if store.items.contains(where: hasUnknownSize) {
                    Text("Le Finder ne donne pas la taille des dossiers : ils ne sont pas comptés dans le total. Pour un total exact, accorde à CorbeillePulse l'accès complet au disque dans Réglages Système › Confidentialité et sécurité.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
