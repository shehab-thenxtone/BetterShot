import CoreFoundation
import Foundation

/// Shows or hides the Finder desktop icons by flipping Finder's `CreateDesktop` preference and restarting Finder,
/// the same thing `defaults write com.apple.finder CreateDesktop` does. Closures are injectable so the logic
/// is testable without touching the real Finder.
public struct DesktopIcons: Sendable {
    private let readCreateDesktop: @Sendable () -> Bool?
    private let writeCreateDesktop: @Sendable (Bool) -> Void
    private let restartFinder: @Sendable () -> Void

    public init(
        readCreateDesktop: @escaping @Sendable () -> Bool?,
        writeCreateDesktop: @escaping @Sendable (Bool) -> Void,
        restartFinder: @escaping @Sendable () -> Void
    ) {
        self.readCreateDesktop = readCreateDesktop
        self.writeCreateDesktop = writeCreateDesktop
        self.restartFinder = restartFinder
    }

    /// The real Finder on this Mac.
    public static let system = DesktopIcons(
        readCreateDesktop: {
            CFPreferencesAppSynchronize("com.apple.finder" as CFString)
            return CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString) as? Bool
        },
        writeCreateDesktop: { value in
            CFPreferencesSetAppValue(
                "CreateDesktop" as CFString,
                value ? kCFBooleanTrue : kCFBooleanFalse,
                "com.apple.finder" as CFString
            )
            CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        },
        restartFinder: {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["Finder"]
            try? process.run() // Finder relaunches itself; no need to wait
        }
    )

    /// Finder shows desktop icons unless `CreateDesktop` is explicitly false.
    public var areHidden: Bool { readCreateDesktop() == false }

    /// Does nothing (and doesn't restart Finder) when the icons are already in the requested state.
    public func setHidden(_ hidden: Bool) {
        guard hidden != areHidden else { return }
        writeCreateDesktop(!hidden)
        restartFinder()
    }
}
