import BetterShotCore
import Foundation

/// Persists the chosen save folder in `UserDefaults`. Falls back to `defaultFolder` when nothing was
/// chosen yet or the chosen folder no longer exists.
public final class UserDefaultsSaveFolderStore: SaveFolderStoring, @unchecked Sendable { // UserDefaults is thread-safe
    private static let key = "saveFolderPath"
    private let defaults: UserDefaults
    private let defaultFolder: URL

    public init(defaults: UserDefaults = .standard, defaultFolder: URL = SystemScreenshotLocation.url) {
        self.defaults = defaults
        self.defaultFolder = defaultFolder
    }

    public var folder: URL {
        guard
            let path = defaults.string(forKey: Self.key),
            Self.isExistingDirectory(path)
        else { return defaultFolder }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public func setFolder(_ url: URL) {
        defaults.set(url.path, forKey: Self.key)
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

/// Where macOS itself saves screenshots (`defaults read com.apple.screencapture location`), else the Desktop.
public enum SystemScreenshotLocation {
    public static var url: URL {
        if
            let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
            !configured.isEmpty
        {
            return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}
