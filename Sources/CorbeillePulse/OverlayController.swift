import AppKit
import CorbeilleCore
import SwiftUI

/// Invisible, click-through window above the Dock, on every Space. It is only on screen
/// while the Trash overflows, so it costs nothing the rest of the time.
@MainActor
final class OverlayController {
    private static let riseAboveDock: CGFloat = 340

    private let store: TrashStore
    private let panel: NSPanel
    private var screenObserver: NSObjectProtocol?

    init(store: TrashStore) {
        self.store = store
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: OverlayView(store: store))
        host.sizingOptions = []
        panel.contentView = host

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.position() }
        }
        position()
        update()
    }

    func update() {
        if store.isOverflowing {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func position() {
        guard let screen = NSScreen.screens.first else { return }
        let full = screen.frame
        // Dock height: 0 when it is auto-hidden or on the side.
        let dockHeight = max(0, screen.visibleFrame.minY - full.minY)
        panel.setFrame(
            NSRect(x: full.minX, y: full.minY, width: full.width, height: dockHeight + Self.riseAboveDock),
            display: false)
    }
}
