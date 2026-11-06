import CorbeilleCore
import Foundation
import Observation

@MainActor
@Observable
final class TrashStore {
    private enum Key {
        static let threshold = "thresholdBytes"
        static let intensity = "overflowIntensity"
    }

    private static let pollInterval: Duration = .seconds(6)

    private(set) var snapshot: TrashSnapshot? { didSet { if snapshot != oldValue { onChange?() } } }
    private(set) var isEmptying = false

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

    /// Called whenever anything shown outside SwiftUI (menu bar, overlay) may need refreshing.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let scanner = TrashScanner()
    @ObservationIgnored private var polling: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let stored = (defaults.object(forKey: Key.threshold) as? NSNumber)?.int64Value
        thresholdBytes = stored.map(Threshold.clamp) ?? Threshold.defaultBytes
        intensity = defaults.string(forKey: Key.intensity).flatMap(Intensity.init) ?? .progressive
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
        // A failed scan is usually a busy Finder: keep showing the last good state.
        if let fresh = try? await scanner.scan() { snapshot = fresh }
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
