import AppKit
import CorbeilleCore
import SwiftUI

struct PanelView: View {
    @Bindable var store: TrashStore
    let updates: UpdateChecker
    let onEmpty: () -> Void
    let onAbout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                problemBanner
                UpdateBanner(updates: updates)
                GaugeView(store: store)
                StatsRow(store: store)
                Button(role: .destructive, action: onEmpty) {
                    Label(store.isEmptying ? String(localized: "Vidage…") : String(localized: "Vider la corbeille"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(store.totalBytes <= 0 || store.isEmptying)
                Divider()
                thresholdSection
                Divider()
                intensitySection
                Divider()
                visibilitySection
                Divider()
                contentsSection
                Button("À propos de CorbeillePulse", action: onAbout)
                    .buttonStyle(.link)
                    .font(.callout)
            }
            .padding(20)
        }
        .frame(minWidth: 390, minHeight: 520)
    }

    @ViewBuilder private var problemBanner: some View {
        if store.accessBlocked {
            banner("Accès à la corbeille requis", systemImage: "exclamationmark.shield") {
                bannerText("macOS protège la corbeille. Autorise CorbeillePulse à contrôler le Finder dans Réglages Système › Confidentialité et sécurité › Automatisation.")
                settingsButton("Ouvrir les réglages", pane: "Privacy_Automation")
            }
        } else if store.scanProblem == .waitingForFinder {
            banner("En attente du Finder", systemImage: "hourglass") {
                bannerText("Le Finder ne répond pas. macOS attend sans doute que tu autorises CorbeillePulse à contrôler le Finder : cherche la fenêtre de demande, ou autorise-la dans Réglages Système › Confidentialité et sécurité › Automatisation.")
                bannerText("Autre solution : accorde à CorbeillePulse l'accès complet au disque, elle lit alors la corbeille sans passer par le Finder.")
                HStack {
                    settingsButton("Ouvrir Automatisation", pane: "Privacy_Automation")
                    settingsButton("Ouvrir Accès complet au disque", pane: "Privacy_AllFiles")
                }
            }
        } else if case .finderError(let message) = store.scanProblem {
            banner("Lecture de la corbeille impossible", systemImage: "exclamationmark.triangle") {
                bannerText("Le Finder a renvoyé une erreur. CorbeillePulse réessaie toutes les quelques secondes. Avec l'accès complet au disque, elle lit la corbeille sans passer par le Finder.")
                if !message.isEmpty {
                    Text(verbatim: message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                settingsButton("Ouvrir Accès complet au disque", pane: "Privacy_AllFiles")
            }
        }
    }

    private func banner<Content: View>(
        _ title: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.orange)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.opacity(0.4)))
    }

    private func bannerText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Opens a pane of System Settings › Privacy & Security.
    private func settingsButton(_ title: LocalizedStringKey, pane: String) -> some View {
        Button(title) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
                NSWorkspace.shared.open(url)
            }
        }
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
            Slider(value: $store.sliderPosition, in: 0...Threshold.sliderMax)
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

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Affichage").font(.headline)
            Toggle("Masquer du Dock", isOn: $store.hideFromDock)
            Toggle("Masquer de la barre de menus", isOn: $store.hideFromMenuBar)
            if store.hideFromDock && store.hideFromMenuBar {
                Text("CorbeillePulse n'apparaît plus ni dans le Dock ni dans la barre de menus. Pour retrouver cette fenêtre, ouvre-la de nouveau depuis le dossier Applications ou Spotlight.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Si tu masques les deux, ouvre de nouveau CorbeillePulse depuis le dossier Applications ou Spotlight pour retrouver cette fenêtre.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if store.hideFromMenuBar {
                Button("Quitter CorbeillePulse") { NSApp.terminate(nil) }
            }
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
                    Image(systemName: store.snapshot == nil ? "hourglass" : "trash").font(.largeTitle).foregroundStyle(.tertiary)
                    Text(store.snapshot == nil ? "Lecture de la corbeille…" : "La corbeille est vide.")
                        .font(.callout).foregroundStyle(.secondary)
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
