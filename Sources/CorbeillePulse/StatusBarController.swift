import AppKit
import CorbeilleCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    /// `nil` while the user hides the app from the menu bar.
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private let store: TrashStore

    init(
        store: TrashStore, updates: UpdateChecker,
        onOpen: @escaping () -> Void, onEmpty: @escaping () -> Void,
        onAbout: @escaping () -> Void, onCheckForUpdates: @escaping () -> Void
    ) {
        self.store = store
        super.init()

        // Every action closes the popover first: it would otherwise sit above the window or alert it opens.
        let view = PopoverView(
            store: store, updates: updates,
            onOpenWindow: { [weak self] in self?.closing(onOpen) },
            onEmpty: { [weak self] in self?.closing(onEmpty) },
            onAbout: { [weak self] in self?.closing(onAbout) },
            onCheckForUpdates: { [weak self] in self?.closing(onCheckForUpdates) })
        let host = NSHostingController(rootView: view)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        setVisible(!store.hideFromMenuBar)
        update()
    }

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            created.button?.target = self
            created.button?.action = #selector(togglePopover)
            item = created
            update()
        } else if !visible, let existing = item {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(existing)
            item = nil
        }
    }

    private func closing(_ action: @escaping () -> Void) {
        // No closing animation: the action may open a modal alert right away.
        popover.close()
        action()
    }

    @objc private func togglePopover() {
        guard let button = item?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Without the Dock icon the app is not active: activate it so the popover takes key focus
        // and closes when the user clicks elsewhere.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        item?.button?.highlight(false)
    }

    func update() {
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
        } else if store.snapshot == nil {
            button.toolTip = String(localized: "Lecture de la corbeille…")
        } else if total <= 0 {
            button.toolTip = String(localized: "Corbeille vide")
        } else if overflowing {
            button.toolTip = String(localized: "Corbeille en débordement : \(formatBytes(total))")
        } else {
            button.toolTip = String(localized: "Corbeille : \(formatBytes(total))")
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

}
