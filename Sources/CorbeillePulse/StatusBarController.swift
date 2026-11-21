import AppKit
import CorbeilleCore

@MainActor
final class StatusBarController: NSObject {
    /// `nil` while the user hides the app from the menu bar.
    private var item: NSStatusItem?
    private let menu = NSMenu()
    private let problemItem = NSMenuItem()
    private let problemSeparator = NSMenuItem.separator()
    private let store: TrashStore
    private let onOpen: () -> Void
    private let onEmpty: () -> Void

    init(store: TrashStore, onOpen: @escaping () -> Void, onEmpty: @escaping () -> Void) {
        self.store = store
        self.onOpen = onOpen
        self.onEmpty = onEmpty
        super.init()

        // Shown only when the Trash cannot be read; it opens the panel, which explains why.
        problemItem.action = #selector(openClicked)
        problemItem.target = self
        problemItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        menu.addItem(problemItem)
        menu.addItem(problemSeparator)
        menu.addItem(makeItem(String(localized: "Ouvrir CorbeillePulse"), #selector(openClicked)))
        menu.addItem(makeItem(String(localized: "Vider la corbeille…"), #selector(emptyClicked)))
        menu.addItem(.separator())
        menu.addItem(makeItem(String(localized: "Quitter"), #selector(quitClicked)))
        setVisible(!store.hideFromMenuBar)
        update()
    }

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            created.menu = menu
            item = created
            update()
        } else if !visible, let existing = item {
            NSStatusBar.system.removeStatusItem(existing)
            item = nil
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    func update() {
        let problem = Self.problemTitle(store)
        problemItem.title = problem ?? ""
        problemItem.isHidden = problem == nil
        problemSeparator.isHidden = problem == nil

        guard let button = item?.button else { return }
        let total = store.totalBytes
        let overflowing = store.isOverflowing

        button.image = Self.icon(filled: total > 0, red: overflowing)
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.title = overflowing ? " \(formatBytes(total))" : ""
        button.imagePosition = .imageLeading

        if store.accessBlocked {
            button.toolTip = String(localized: "CorbeillePulse : accès à la corbeille requis")
        } else if store.scanProblem == .waitingForFinder {
            button.toolTip = String(localized: "CorbeillePulse : en attente du Finder")
        } else if store.scanProblem != nil {
            button.toolTip = String(localized: "CorbeillePulse : lecture de la corbeille impossible")
        } else if total <= 0 {
            button.toolTip = String(localized: "Corbeille vide")
        } else if overflowing {
            button.toolTip = String(localized: "Corbeille en débordement : \(formatBytes(total))")
        } else {
            button.toolTip = String(localized: "Corbeille : \(formatBytes(total))")
        }
    }

    private static func problemTitle(_ store: TrashStore) -> String? {
        if store.accessBlocked { return String(localized: "Accès à la corbeille requis…") }
        switch store.scanProblem {
        case .waitingForFinder: return String(localized: "En attente du Finder…")
        case .finderError: return String(localized: "Lecture de la corbeille impossible…")
        case nil: return nil
        }
    }

    private static func icon(filled: Bool, red: Bool) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if red {
            configuration = configuration.applying(.init(paletteColors: [.systemRed]))
        }
        let image = NSImage(systemSymbolName: filled ? "trash.fill" : "trash", accessibilityDescription: String(localized: "Corbeille"))?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = !red
        return image
    }

    @objc private func openClicked() { onOpen() }
    @objc private func emptyClicked() { onEmpty() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
