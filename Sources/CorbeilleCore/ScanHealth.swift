import Foundation

/// Why the Trash could not be read, as shown to the user.
public enum ScanProblem: Equatable, Sendable {
    /// Finder never answered: usually the Automation consent dialog is still waiting.
    case waitingForFinder
    /// Finder answered with an error.
    case finderError(String)
}

/// Turns the outcome of each scan into the problem to show, if any. A busy Finder fails now
/// and then: once a good snapshot exists, it is kept on screen and only repeated failures are
/// reported. Before the first good snapshot there is nothing to show, so the first failure is.
public struct ScanHealth: Equatable, Sendable {
    /// Consecutive failures tolerated silently once a good snapshot exists.
    public static let toleratedFailures = 2

    public private(set) var problem: ScanProblem?
    public private(set) var hasSucceeded = false
    private var consecutiveFailures = 0

    public init() {}

    public mutating func recordSuccess() {
        hasSucceeded = true
        consecutiveFailures = 0
        problem = nil
    }

    public mutating func recordFailure(_ error: Error) {
        consecutiveFailures += 1
        guard !hasSucceeded || consecutiveFailures > Self.toleratedFailures else { return }
        switch error as? TrashError {
        case .timedOut: problem = .waitingForFinder
        case .scriptFailed(let message): problem = .finderError(message)
        default: problem = .finderError(error.localizedDescription)
        }
    }
}
