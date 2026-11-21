import CorbeilleCore
import Foundation
import Observation

/// Asks GitHub for the latest release. The app is not notarized, so it never installs anything:
/// it only points to the release page, where the DMG is.
@MainActor
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, page: URL)
        case failed(String)
    }

    static let repositoryPage = URL(string: "https://github.com/vince749/corbeillepulse")!
    private static let latestRelease = URL(string: "https://api.github.com/repos/vince749/corbeillepulse/releases/latest")!
    /// GitHub allows 60 anonymous requests an hour: one check at launch, then one a day, is plenty.
    private static let automaticInterval: Duration = .seconds(24 * 60 * 60)

    private(set) var state: State = .idle

    /// `nil` when running outside an app bundle (`swift run`).
    let currentVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let build: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

    @ObservationIgnored private var schedule: Task<Void, Never>?

    var availableVersion: String? {
        if case .available(let version, _) = state { return version }
        return nil
    }

    var releasePage: URL {
        if case .available(_, let page) = state { return page }
        return Self.repositoryPage.appendingPathComponent("releases/latest")
    }

    /// Checks at launch, then once a day, silently: a failure only shows when checking by hand.
    func startAutomaticChecks() {
        guard schedule == nil else { return }
        schedule = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check(manual: false)
                try? await Task.sleep(for: Self.automaticInterval)
            }
        }
    }

    func check(manual: Bool = true) async {
        guard state != .checking else { return }
        let previous = state
        state = .checking
        do {
            var request = URLRequest(url: Self.latestRelease, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            if let current = currentVersion.flatMap(AppVersion.init), release.isNewer(than: current) {
                state = .available(version: release.version?.description ?? release.tagName, page: release.htmlURL)
            } else {
                state = .upToDate
            }
        } catch {
            // An automatic check that fails keeps whatever was known before, without bothering anyone.
            state = manual ? .failed(error.localizedDescription) : previous
        }
    }
}
