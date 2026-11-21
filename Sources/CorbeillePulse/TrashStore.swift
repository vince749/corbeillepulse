import CorbeilleCore
import Foundation
import Observation

@MainActor
@Observable
final class TrashStore {
    private enum Key {
        static let threshold = "thresholdBytes"
        static let intensity = "overflowIntensity"
        static let hideFromDock = "hideFromDock"
        static let hideFromMenuBar = "hideFromMenuBar"
    }

    /// Read before the store exists, so the Dock icon never flashes at launch.
    static var storedHideFromDock: Bool { UserDefaults.standard.bool(forKey: Key.hideFromDock) }

    private static let pollInterval: Duration = .seconds(6)

    private(set) var snapshot: TrashSnapshot? { didSet { if snapshot != oldValue { onChange?() } } }
    private(set) var isEmptying = false
    /// Why the Trash cannot be read right now, if it cannot (the last good snapshot stays shown).
    private(set) var scanProblem: ScanProblem? { didSet { if scanProblem != oldValue { onChange?() } } }

    var thresholdBytes: Int64 {
        didSet {
            guard thresholdBytes != oldValue else { return }
            UserDefaults.standard.set(thresholdBytes, forKey: Key.threshold)
            onChange?()
        }
    }

    var intensity: Intensity {
        didSet {
            guard intensity != oldValue else { return }
            UserDefaults.standard.set(intensity.rawValue, forKey: Key.intensity)
            onChange?()
        }
    }

    var hideFromDock: Bool {
        didSet {
            guard hideFromDock != oldValue else { return }
            UserDefaults.standard.set(hideFromDock, forKey: Key.hideFromDock)
            onVisibilityChange?()
        }
    }

    var hideFromMenuBar: Bool {
        didSet {
            guard hideFromMenuBar != oldValue else { return }
            UserDefaults.standard.set(hideFromMenuBar, forKey: Key.hideFromMenuBar)
            onVisibilityChange?()
        }
    }

    /// Called whenever anything shown outside SwiftUI (menu bar, overlay) may need refreshing.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Called when the Dock or menu bar setting changes.
    @ObservationIgnored var onVisibilityChange: (() -> Void)?
    @ObservationIgnored private var health = ScanHealth()
    @ObservationIgnored private let scanner = TrashScanner()
    @ObservationIgnored private var polling: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let stored = (defaults.object(forKey: Key.threshold) as? NSNumber)?.int64Value
        thresholdBytes = stored.map(Threshold.clamp) ?? Threshold.defaultBytes
        intensity = defaults.string(forKey: Key.intensity).flatMap(Intensity.init) ?? .progressive
        hideFromDock = defaults.bool(forKey: Key.hideFromDock)
        hideFromMenuBar = defaults.bool(forKey: Key.hideFromMenuBar)
    }

    var totalBytes: Int64 { snapshot?.totalBytes ?? 0 }
    var itemCount: Int { snapshot?.itemCount ?? 0 }
    var items: [TrashItem] { snapshot?.items ?? [] }
    var accessBlocked: Bool { snapshot?.accessBlocked ?? false }
    var fillRatio: Double { Double(totalBytes) / Double(thresholdBytes) }
    var isOverflowing: Bool { totalBytes > 0 && fillRatio >= 1 }

    func startPolling() {
        guard polling == nil else { return }
        polling = Task { [weak self] in
            // The next scan starts only once this one ends, so a slow Finder is never piled on.
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    private func refresh() async {
        // A failed scan is usually a busy Finder: keep showing the last good state,
        // and let `ScanHealth` decide when the failure is worth telling the user.
        do {
            snapshot = try await scanner.scan()
            health.recordSuccess()
        } catch {
            health.recordFailure(error)
        }
        scanProblem = health.problem
    }

    /// Returns how many items could not be removed.
    func empty() async throws -> Int {
        isEmptying = true
        defer { isEmptying = false }
        try await scanner.empty()
        await refresh()
        return itemCount
    }
}
