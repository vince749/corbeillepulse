import Foundation

public enum Intensity: String, CaseIterable, Sendable {
    case light, progressive, dramatic
}

public enum TrashItemKind: String, Sendable {
    case image, video, audio, document, archive, code, app, folder, file

    private static let byExtension: [String: TrashItemKind] = {
        let groups: [(TrashItemKind, [String])] = [
            (.image, ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg"]),
            (.video, ["mp4", "mov", "avi", "mkv", "webm", "m4v"]),
            (.audio, ["mp3", "wav", "aac", "flac", "m4a", "aiff"]),
            (.document, ["pdf", "doc", "docx", "pages", "txt", "rtf", "key", "ppt", "pptx", "xls", "xlsx", "numbers", "md"]),
            (.archive, ["zip", "rar", "gz", "tar", "dmg", "7z"]),
            (.code, ["js", "ts", "tsx", "jsx", "py", "json", "html", "css", "c", "cpp", "java", "rb", "go", "rs", "sh", "swift"]),
        ]
        var map: [String: TrashItemKind] = [:]
        for (kind, extensions) in groups {
            for ext in extensions { map[ext] = kind }
        }
        return map
    }()

    public static func of(name: String, isDirectory: Bool) -> TrashItemKind {
        if name.hasSuffix(".app") { return .app }
        if isDirectory { return .folder }
        return byExtension[(name as NSString).pathExtension.lowercased()] ?? .file
    }
}

public struct TrashItem: Identifiable, Equatable, Sendable {
    public let name: String
    public let bytes: Int64
    public let kind: TrashItemKind
    public var id: String { name }

    public init(name: String, bytes: Int64, kind: TrashItemKind) {
        self.name = name
        self.bytes = bytes
        self.kind = kind
    }
}

public struct TrashSnapshot: Equatable, Sendable {
    public static let maxItems = 60

    public let totalBytes: Int64
    public let itemCount: Int
    /// Largest entries first, capped at `maxItems`.
    public let items: [TrashItem]
    /// True when macOS refused access to the Trash.
    public let accessBlocked: Bool

    public init(allItems: [TrashItem], accessBlocked: Bool = false) {
        totalBytes = allItems.reduce(0) { $0 + $1.bytes }
        itemCount = allItems.count
        items = Array(allItems.sorted { $0.bytes > $1.bytes }.prefix(Self.maxItems))
        self.accessBlocked = accessBlocked
    }
}

public enum Threshold {
    public static let minBytes: Int64 = 1024 * 1024
    public static let maxBytes: Int64 = 50 * 1024 * 1024 * 1024
    public static let defaultBytes: Int64 = 100 * 1024 * 1024
    public static let sliderMax = 1000.0

    public static func clamp(_ bytes: Int64) -> Int64 { min(maxBytes, max(minBytes, bytes)) }

    public static func sliderPosition(forBytes bytes: Int64) -> Double {
        let ratio = Double(clamp(bytes)) / Double(minBytes)
        let range = Double(maxBytes) / Double(minBytes)
        return (sliderMax * log(ratio) / log(range)).rounded()
    }

    public static func bytes(forSliderPosition position: Double) -> Int64 {
        let range = Double(maxBytes) / Double(minBytes)
        return clamp(Int64((Double(minBytes) * pow(range, position / sliderMax)).rounded()))
    }
}

public func formatBytes(_ bytes: Int64) -> String {
    if bytes <= 0 { return "0 o" }
    let units = ["o", "Ko", "Mo", "Go", "To"]
    let index = min(units.count - 1, Int(floor(log(Double(bytes)) / log(1024))))
    let value = Double(bytes) / pow(1024, Double(index))
    if value >= 100 || index == 0 { return "\(Int(value.rounded())) \(units[index])" }
    return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value) + " " + units[index]
}
