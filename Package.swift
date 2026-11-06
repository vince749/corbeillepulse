// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CorbeillePulse",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CorbeilleCore"),
        .executableTarget(name: "CorbeillePulse", dependencies: ["CorbeilleCore"]),
        .testTarget(name: "CorbeilleCoreTests", dependencies: ["CorbeilleCore"]),
    ]
)
