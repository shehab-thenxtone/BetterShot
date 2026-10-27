import BetterShotCore
import Foundation

/// Finds the folder a Google Drive or OneDrive desktop app syncs, by looking where macOS mounts them
/// (`~/Library/CloudStorage`) and the older home-folder locations.
public struct SyncedFolderLocator: Sendable {
    private let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    /// The folder files should be copied into, or nil when the desktop app isn't set up (or hasn't created it yet).
    public func detect(for provider: CloudProvider) -> URL? {
        let cloudStorage = homeDirectory.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let mounts = SyncedFolder.ordered(names(in: cloudStorage).filter { SyncedFolder.isMountName($0, for: provider) })
            .map { cloudStorage.appendingPathComponent($0, isDirectory: true) }
        let legacy = SyncedFolder.ordered(names(in: homeDirectory).filter { SyncedFolder.isLegacyName($0, for: provider) })
            .map { homeDirectory.appendingPathComponent($0, isDirectory: true) }

        for root in mounts + legacy {
            let target = SyncedFolder.uploadSubfolder(for: provider).map { root.appendingPathComponent($0, isDirectory: true) } ?? root
            if Self.isDirectory(target) { return target }
        }
        return nil
    }

    private func names(in directory: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    fileprivate static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

/// The folder to use for each provider: the one the user picked if it still exists, otherwise the detected one.
public final class SyncedFolders: @unchecked Sendable { // UserDefaults is thread-safe
    private let defaults: UserDefaults
    private let locator: SyncedFolderLocator

    public init(defaults: UserDefaults = .standard, locator: SyncedFolderLocator = SyncedFolderLocator()) {
        self.defaults = defaults
        self.locator = locator
    }

    public func folder(for provider: CloudProvider) -> URL? {
        chosenFolder(for: provider) ?? locator.detect(for: provider)
    }

    /// The folder the user picked, if it still exists.
    public func chosenFolder(for provider: CloudProvider) -> URL? {
        guard let path = defaults.string(forKey: Self.key(provider)) else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return SyncedFolderLocator.isDirectory(url) ? url : nil
    }

    /// Remembers `url` for `provider`; nil goes back to the detected folder.
    public func choose(_ url: URL?, for provider: CloudProvider) {
        if let url {
            defaults.set(url.path, forKey: Self.key(provider))
        } else {
            defaults.removeObject(forKey: Self.key(provider))
        }
    }

    private static func key(_ provider: CloudProvider) -> String { "syncedFolderPath.\(provider.rawValue)" }
}
