import AppKit
import CorbeilleCore
import SwiftUI

@main
enum Entry {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TrashStore()
    private var window: NSWindow?
    private var statusBar: StatusBarController?
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        statusBar = StatusBarController(
            store: store,
            onOpen: { [weak self] in self?.showWindow() },
            onEmpty: { [weak self] in self?.confirmAndEmpty() })
        overlay = OverlayController(store: store)
        store.onChange = { [weak self] in
            self?.statusBar?.update()
            self?.overlay?.update()
        }
        store.startPolling()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func showWindow() {
        if window == nil {
            let view = PanelView(store: store, onEmpty: { [weak self] in self?.confirmAndEmpty() })
            let created = NSWindow(contentViewController: NSHostingController(rootView: view))
            created.title = String(localized: "Corbeille")
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.setContentSize(NSSize(width: 460, height: 720))
            created.contentMinSize = NSSize(width: 390, height: 520)
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func confirmAndEmpty() {
        guard !store.isEmptying else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Vider la corbeille ?")
        alert.informativeText = String(
            localized: "\(store.itemCount) élément(s), \(formatBytes(store.totalBytes)) : suppression définitive.")
        let confirm = alert.addButton(withTitle: String(localized: "Vider la corbeille"))
        confirm.hasDestructiveAction = true
        let cancel = alert.addButton(withTitle: String(localized: "Annuler"))
        // Entrée annule : une suppression définitive doit rester un geste délibéré.
        confirm.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                let remaining = try await store.empty()
                if remaining > 0 { showError(String(localized: "\(remaining) élément(s) n'ont pas pu être supprimés.")) }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "Échec du vidage")
        alert.informativeText = message
        alert.runModal()
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "Masquer CorbeillePulse"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quitter CorbeillePulse"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: String(localized: "Fenêtre"))
        windowMenu.addItem(withTitle: String(localized: "Fermer"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: String(localized: "Réduire"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        return main
    }
}
