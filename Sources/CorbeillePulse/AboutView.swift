import AppKit
import SwiftUI

/// Shown above the figures when GitHub has a newer release.
struct UpdateBanner: View {
    let updates: UpdateChecker
    var compact = false

    var body: some View {
        if let version = updates.availableVersion {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue)
                Text("Version \(version) disponible")
                    .font(compact ? .callout.weight(.medium) : .headline)
                Spacer(minLength: 4)
                Button("Télécharger") { NSWorkspace.shared.open(updates.releasePage) }
                    .controlSize(compact ? .small : .regular)
            }
            .padding(compact ? 8 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct AboutView: View {
    let updates: UpdateChecker

    private var versionText: String {
        guard let version = updates.currentVersion else { return String(localized: "Version de développement") }
        if let build = updates.build { return String(localized: "Version \(version) (\(build))") }
        return String(localized: "Version \(version)")
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text(verbatim: "CorbeillePulse").font(.title2.weight(.semibold))
                Text(versionText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Surveille la corbeille et la fait déborder par-dessus le Dock quand elle dépasse le seuil choisi.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Link("Code source sur GitHub", destination: UpdateChecker.repositoryPage)
                .font(.callout)

            Divider()
            updateSection
        }
        .padding(24)
        .frame(width: 320)
    }

    @ViewBuilder private var updateSection: some View {
        VStack(spacing: 10) {
            switch updates.state {
            case .idle:
                EmptyView()
            case .checking:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Recherche en cours…").font(.callout).foregroundStyle(.secondary)
                }
            case .upToDate:
                Label("CorbeillePulse est à jour.", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            case .available(let version, let page):
                Label("La version \(version) est disponible.", systemImage: "arrow.down.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.blue)
                Button("Télécharger la version \(version)") { NSWorkspace.shared.open(page) }
                    .buttonStyle(.borderedProminent)
            case .failed(let message):
                VStack(spacing: 2) {
                    Label("Impossible de joindre GitHub.", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    Text(verbatim: message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            if updates.availableVersion == nil {
                Button("Rechercher les mises à jour") { Task { await updates.check() } }
                    .disabled(updates.state == .checking)
            }
        }
    }
}
