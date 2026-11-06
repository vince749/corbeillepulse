import Foundation
import Testing

@testable import CorbeilleCore

@Test func formatsBytesLikeTheOriginalApp() {
    #expect(formatBytes(0) == "0 o")
    #expect(formatBytes(512) == "512 o")
    #expect(formatBytes(1536) == "1.5 Ko")
    #expect(formatBytes(150 * 1024 * 1024) == "150 Mo")
    #expect(formatBytes(5_809_000_000) == "5.4 Go")
}

@Test func recognisesKinds() {
    #expect(TrashItemKind.of(name: "Safari.app", isDirectory: true) == .app)
    #expect(TrashItemKind.of(name: "Photos", isDirectory: true) == .folder)
    #expect(TrashItemKind.of(name: "a.JPG", isDirectory: false) == .image)
    #expect(TrashItemKind.of(name: "sans-extension", isDirectory: false) == .file)
}

@Test func sliderRoundTripsAndStaysInRange() {
    #expect(Threshold.sliderPosition(forBytes: Threshold.minBytes) == 0)
    #expect(Threshold.sliderPosition(forBytes: Threshold.maxBytes) == 1000)
    #expect(Threshold.bytes(forSliderPosition: 0) == Threshold.minBytes)
    #expect(Threshold.bytes(forSliderPosition: 1000) == Threshold.maxBytes)
    for position in stride(from: 0.0, through: 1000, by: 37) {
        #expect(Threshold.sliderPosition(forBytes: Threshold.bytes(forSliderPosition: position)) == position)
    }
}

@Test func generatorMatchesTheOriginalLayout() {
    // Reference values computed from the original JavaScript implementation.
    let random = PileLayout.generator(seed: 0x9E37_79B9)
    #expect(random() == 0.3588899802416563)
    #expect(random() == 0.10590326134115458)
    #expect(random() == 0.675290479324758)
}

@Test func pileAppearsOnlyPastTheThresholdAndGrows() throws {
    #expect(PileLayout.metrics(fillRatio: 0.99, intensity: .dramatic, areaWidth: 1000, areaHeight: 400) == nil)
    let start = try #require(PileLayout.metrics(fillRatio: 1, intensity: .progressive, areaWidth: 1000, areaHeight: 400))
    #expect(start.width == 220)
    #expect(start.pieceCount == 3)
    let later = try #require(PileLayout.metrics(fillRatio: 3, intensity: .progressive, areaWidth: 1000, areaHeight: 400))
    #expect(later.width > start.width && later.height > start.height && later.pieceCount > start.pieceCount)
    let huge = try #require(PileLayout.metrics(fillRatio: 1e6, intensity: .dramatic, areaWidth: 1000, areaHeight: 400))
    #expect(huge.pieceCount <= PileLayout.poolSize)
    #expect(huge.width <= 970 && huge.height <= 392)
}

@Test func parsesFinderOutput() {
    var cache: [String: Int64] = [:]
    let sep = "\u{1F}"
    let output = "3\n99\nphoto.png\(sep)1.2345678E+7\(sep)0\nDossier é\(sep)2048\(sep)1\nvirgule.zip\(sep)1,5E+3\(sep)0\n"
    let snapshot = parseFinderOutput(output, cache: &cache)
    #expect(snapshot.itemCount == 3)
    #expect(snapshot.totalBytes == 12_345_678 + 2048 + 1500)
    #expect(snapshot.items.first == TrashItem(name: "photo.png", bytes: 12_345_678, kind: .image))
    #expect(snapshot.items.contains(TrashItem(name: "Dossier é", bytes: 2048, kind: .folder)))
}

@Test func finderSizesOnlyGrowAndArePruned() {
    var cache: [String: Int64] = [:]
    let sep = "\u{1F}"
    _ = parseFinderOutput("1\n0\na\(sep)500\(sep)0\n", cache: &cache)
    let flicker = parseFinderOutput("1\n0\na\(sep)0\(sep)0\n", cache: &cache)
    #expect(flicker.totalBytes == 500)
    let empty = parseFinderOutput("0\n0\n", cache: &cache)
    #expect(empty.totalBytes == 0)
    #expect(cache.isEmpty)
}

@Test func snapshotCapsItemsButCountsEverything() {
    let items = (0..<100).map { TrashItem(name: "f\($0)", bytes: Int64($0), kind: .file) }
    let snapshot = TrashSnapshot(allItems: items)
    #expect(snapshot.itemCount == 100)
    #expect(snapshot.items.count == TrashSnapshot.maxItems)
    #expect(snapshot.items.first?.bytes == 99)
    #expect(snapshot.totalBytes == 4950)
}

@Test func scansAFolderAndIgnoresSystemFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let folder = root.appendingPathComponent("dossier")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(count: 100).write(to: root.appendingPathComponent("a.png"))
    try Data(count: 50).write(to: root.appendingPathComponent(".DS_Store"))
    try Data(count: 200).write(to: folder.appendingPathComponent("b.txt"))

    let snapshot = try #require(TrashScanner.scanFileSystem(root))
    #expect(snapshot.itemCount == 2)
    #expect(snapshot.totalBytes == 300)
    #expect(TrashScanner.scanFileSystem(root.appendingPathComponent("absent")) == nil)
}

@Test func runsAppleScriptAndReportsFailures() async throws {
    let ok = try await runAppleScript(#"return "é€""#, timeout: 10)
    #expect(ok.status == 0)
    #expect(ok.output.trimmingCharacters(in: .newlines) == "é€")

    let timedOut = try await runAppleScript("delay 30", timeout: 0.5)
    #expect(timedOut.timedOut)
}

/// Reads the real Trash through Finder. Only runs with CP_LIVE=1, and never modifies anything.
@Test(.enabled(if: ProcessInfo.processInfo.environment["CP_LIVE"] == "1"))
func readsTheRealTrash() async throws {
    let scanner = TrashScanner()
    let snapshot = try await scanner.scan()
    #expect(!snapshot.accessBlocked)
    print("live trash: \(snapshot.itemCount) items, \(formatBytes(snapshot.totalBytes))")
}
