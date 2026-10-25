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
        // Side-effecting implementations of Core protocols (ScreenCaptureKit, storage).
        .target(name: "BetterShotServices", dependencies: ["BetterShotCore"]),
        .executableTarget(name: "BetterShot", dependencies: ["BetterShotCore", "BetterShotServices"]),
        .testTarget(name: "BetterShotCoreTests", dependencies: ["BetterShotCore"]),
        .testTarget(name: "BetterShotServicesTests", dependencies: ["BetterShotCore", "BetterShotServices"]),
    ]
)
