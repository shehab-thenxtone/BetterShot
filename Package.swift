// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterShot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BetterShot", targets: ["BetterShot"]),
    ],
    targets: [
        // Pure Swift domain layer: no AppKit, no I/O.
        .target(name: "BetterShotCore"),
        .executableTarget(name: "BetterShot", dependencies: ["BetterShotCore"]),
        .testTarget(name: "BetterShotCoreTests", dependencies: ["BetterShotCore"]),
    ]
)
