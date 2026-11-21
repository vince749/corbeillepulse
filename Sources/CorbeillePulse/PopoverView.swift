import AppKit
import CorbeilleCore
import SwiftUI

/// The small version of the window, opened from the menu bar icon.
struct PopoverView: View {
    @Bindable var store: TrashStore
    let updates: UpdateChecker
    let onOpenWindow: () -> Void
    let onEmpty: () -> Void
    let onAbout: () -> Void
    let onCheckForUpdates: () -> Void

    private var problem: String? {
        if store.accessBlocked { return String(localized: "Accès à la corbeille requis") }
        switch store.scanProblem {
        case .waitingForFinder: return String(localized: "En attente du Finder")
        case .finderError: return String(localized: "Lecture de la corbeille impossible")
        case nil: return nil
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if let problem {
                Button(action: onOpenWindow) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(problem).font(.callout.weight(.medium))
                        Spacer(minLength: 4)
                        Text("Détails").font(.callout)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            UpdateBanner(updates: updates, compact: true)

            GaugeView(store: store, diameter: 116, lineWidth: 10)
            StatsRow(store: store, compact: true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Seuil de débordement").font(.callout.weight(.medium))
                    Spacer()
                    Text(formatBytes(store.thresholdBytes))
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $store.sliderPosition, in: 0...Threshold.sliderMax)
                    .controlSize(.small)
                Picker("Intensité du débordement", selection: $store.intensity) {
                    Text("Léger").tag(Intensity.light)
                    Text("Progressif").tag(Intensity.progressive)
                    Text("Dramatique").tag(Intensity.dramatic)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .padding(.top, 4)
            }

            Button(role: .destructive, action: onEmpty) {
                Label(store.isEmptying ? String(localized: "Vidage…") : String(localized: "Vider la corbeille"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(store.totalBytes <= 0 || store.isEmptying)

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var footer: some View {
        HStack {
            Button(action: onOpenWindow) {
                Label("Ouvrir CorbeillePulse", systemImage: "macwindow")
            }
            .buttonStyle(.borderless)
            Spacer()
            Menu {
                Button("À propos de CorbeillePulse", action: onAbout)
                Button("Rechercher les mises à jour…", action: onCheckForUpdates)
                Divider()
                Button("Quitter CorbeillePulse") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(String(localized: "Plus"))
        }
        .font(.callout)
    }
}
