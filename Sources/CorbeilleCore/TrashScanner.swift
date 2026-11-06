import Foundation

public enum TrashError: Error, Equatable, LocalizedError {
    /// macOS refused the Automation permission for Finder.
    case notAuthorized
    case timedOut
    case scriptFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized: "CorbeillePulse n'est pas autorisée à contrôler le Finder."
        case .timedOut: "Le Finder n'a pas répondu à temps."
        case .scriptFailed(let message): message
        }
    }
}

struct ScriptRun: Sendable {
    let output: String
    let errorOutput: String
    let status: Int32
    let timedOut: Bool
}

/// Runs AppleScript in a child process: Finder can be slow, and this must never block the UI.
func runAppleScript(_ source: String, timeout: TimeInterval) async throws -> ScriptRun {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let timeoutFlag = LockedFlag()
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            let timer = DispatchWorkItem {
                timeoutFlag.set()
                process.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)

            // Both pipes must be drained at once, or a large output blocks the child.
            let errorBox = DataBox()
            let readers = DispatchGroup()
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                errorBox.data = stderr.fileHandleForReading.readDataToEndOfFile()
                readers.leave()
            }
            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            readers.wait()
            process.waitUntilExit()
            timer.cancel()

            continuation.resume(returning: ScriptRun(
                output: String(decoding: outputData, as: UTF8.self),
                errorOutput: String(decoding: errorBox.data, as: UTF8.self),
                status: process.terminationStatus,
                timedOut: timeoutFlag.isSet))
        }
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
}

/// Parses the output of `TrashScanner.readScript`. Finder's `size` is flaky: it reports
/// nothing for items it has not computed yet, so `cache` keeps the largest size seen per item.
public func parseFinderOutput(_ output: String, cache: inout [String: Int64]) -> TrashSnapshot {
    var items: [TrashItem] = []
    var seen = Set<String>()
    for line in output.components(separatedBy: "\n").dropFirst(2) where !line.isEmpty {
        let fields = line.components(separatedBy: "\u{1F}")
        guard fields.count >= 3 else { continue }
        let name = fields[0]
        // AppleScript prints reals like 1.2345678E+10, with a comma on some locales.
        let reported = Double(fields[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        let best = max(Int64(reported.rounded()), cache[name] ?? 0)
        cache[name] = best
        seen.insert(name)
        let isDirectory = fields[2].trimmingCharacters(in: .whitespaces) == "1"
        items.append(TrashItem(name: name, bytes: best, kind: .of(name: name, isDirectory: isDirectory)))
    }
    cache = cache.filter { seen.contains($0.key) }
    return TrashSnapshot(allItems: items)
}

/// Reads `~/.Trash` directly when the app has Full Disk Access. Otherwise macOS denies it,
/// and the scanner asks Finder instead, which only needs a one-click Automation approval.
public actor TrashScanner {
    private enum Source { case fileSystem, finder }

    private static let readScript = """
        tell application "Finder"
        \tset theItems to items in trash
        \tset total to 0
        \tset out to ""
        \trepeat with anItem in theItems
        \t\tset sz to 0
        \t\ttry
        \t\t\tset sz to size of anItem
        \t\tend try
        \t\tif sz is missing value then set sz to 0
        \t\tset total to total + sz
        \t\tset isF to "0"
        \t\tif class of anItem is folder then set isF to "1"
        \t\tset out to out & (name of anItem) & (character id 31) & (sz as text) & (character id 31) & isF & linefeed
        \tend repeat
        \treturn ((count of theItems) as text) & linefeed & (total as text) & linefeed & out
        end tell
        """

    private let trashURL: URL
    private var source = Source.fileSystem
    private var finderSizes: [String: Int64] = [:]

    public init(trashURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")) {
        self.trashURL = trashURL
    }

    /// Throws on a temporary failure: callers should keep showing the last good snapshot.
    public func scan() async throws -> TrashSnapshot {
        if source == .fileSystem {
            if let snapshot = Self.scanFileSystem(trashURL) { return snapshot }
            source = .finder
        }
        do {
            let run = try await runAppleScript(Self.readScript, timeout: 25)
            try Self.check(run)
            return parseFinderOutput(run.output, cache: &finderSizes)
        } catch TrashError.notAuthorized {
            return TrashSnapshot(allItems: [], accessBlocked: true)
        }
    }

    public func empty() async throws {
        let run = try await runAppleScript(#"tell application "Finder" to empty the trash"#, timeout: 120)
        try Self.check(run)
        finderSizes.removeAll()
    }

    private static func check(_ run: ScriptRun) throws {
        if run.timedOut { throw TrashError.timedOut }
        guard run.status != 0 else { return }
        let message = run.errorOutput
        if message.contains("-1743") || message.contains("Not authorized") || message.contains("not allowed") {
            throw TrashError.notAuthorized
        }
        throw TrashError.scriptFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// `nil` when the folder cannot be read, which is the normal case without Full Disk Access.
    static func scanFileSystem(_ directory: URL) -> TrashSnapshot? {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return nil }
        let items = names
            .filter { $0 != ".DS_Store" && !$0.hasPrefix(".localized") }
            .map { name -> TrashItem in
                let url = directory.appendingPathComponent(name)
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                let isDirectory = values?.isDirectory == true && values?.isSymbolicLink != true
                let bytes = isDirectory ? directorySize(url) : fileSize(url)
                return TrashItem(name: name, bytes: bytes, kind: .of(name: name, isDirectory: isDirectory))
            }
        return TrashSnapshot(allItems: items)
    }

    private static func fileSize(_ url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let walker = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [], errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let child as URL in walker {
            guard let values = try? child.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                values.isRegularFile == true
            else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
