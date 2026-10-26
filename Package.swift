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
        // Annotation document model, undo history and CoreGraphics flattening. No UI, no dependencies.
        .target(name: "BetterShotAnnotations"),
        // Side-effecting implementations of Core protocols (ScreenCaptureKit, storage).
        .target(name: "BetterShotServices", dependencies: ["BetterShotCore", "BetterShotAnnotations"]),
        .executableTarget(name: "BetterShot", dependencies: ["BetterShotCore", "BetterShotServices"]),
        .testTarget(name: "BetterShotCoreTests", dependencies: ["BetterShotCore"]),
        .testTarget(name: "BetterShotServicesTests", dependencies: ["BetterShotCore", "BetterShotServices"]),
        .testTarget(name: "BetterShotAnnotationsTests", dependencies: ["BetterShotAnnotations"]),
    ]
)
