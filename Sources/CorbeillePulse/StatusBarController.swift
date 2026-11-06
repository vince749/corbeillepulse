import AppKit
import CorbeilleCore

@MainActor
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: TrashStore
    private let onOpen: () -> Void
    private let onEmpty: () -> Void

    init(store: TrashStore, onOpen: @escaping () -> Void, onEmpty: @escaping () -> Void) {
        self.store = store
        self.onOpen = onOpen
        self.onEmpty = onEmpty
        super.init()

        let menu = NSMenu()
        menu.addItem(makeItem("Ouvrir CorbeillePulse", #selector(openClicked)))
        menu.addItem(makeItem("Vider la corbeille…", #selector(emptyClicked)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quitter", #selector(quitClicked)))
        item.menu = menu
        update()
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    func update() {
        guard let button = item.button else { return }
        let total = store.totalBytes
        let overflowing = store.isOverflowing

        button.image = Self.icon(filled: total > 0, red: overflowing)
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.title = overflowing ? " \(formatBytes(total))" : ""
        button.imagePosition = .imageLeading

        if store.accessBlocked {
            button.toolTip = "CorbeillePulse : accès à la corbeille requis"
        } else if total <= 0 {
            button.toolTip = "Corbeille vide"
        } else if overflowing {
            button.toolTip = "Corbeille en débordement : \(formatBytes(total))"
        } else {
            button.toolTip = "Corbeille : \(formatBytes(total))"
        }
    }

    private static func icon(filled: Bool, red: Bool) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if red {
            configuration = configuration.applying(.init(paletteColors: [.systemRed]))
        }
        let image = NSImage(systemSymbolName: filled ? "trash.fill" : "trash", accessibilityDescription: "Corbeille")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = !red
        return image
    }

    @objc private func openClicked() { onOpen() }
    @objc private func emptyClicked() { onEmpty() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
