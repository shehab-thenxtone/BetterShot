import Foundation

/// What BetterShot knows about the folders that the Google Drive and OneDrive desktop apps keep in sync, so an
/// image can be copied there and uploaded by those apps, with no sign-in or app registration of our own.
public enum SyncedFolder {
    /// A directory of `~/Library/CloudStorage`: Google Drive mounts as `GoogleDrive-<account>`, OneDrive as
    /// `OneDrive` or `OneDrive-<name>` (`OneDrive-Personal`, `OneDrive-<organisation>`).
    public static func isMountName(_ name: String, for provider: CloudProvider) -> Bool {
        switch provider {
        case .googleDrive: name.hasPrefix("GoogleDrive-")
        case .oneDrive: name == "OneDrive" || name.hasPrefix("OneDrive-")
        }
    }

    /// A folder in the home directory, where older versions of the desktop apps (and shortcuts to the mounts) live.
    public static func isLegacyName(_ name: String, for provider: CloudProvider) -> Bool {
        switch provider {
        case .googleDrive: name == "Google Drive"
        case .oneDrive: name == "OneDrive" || name.hasPrefix("OneDrive - ")
        }
    }

    /// The folder inside a mount that holds the user's own files. A Google Drive mount also lists shared drives and
    /// other roots beside `My Drive`; a OneDrive mount is the files folder itself.
    public static func uploadSubfolder(for provider: CloudProvider) -> String? {
        provider == .googleDrive ? "My Drive" : nil
    }

    /// Personal accounts first (a screenshot rarely belongs in a work drive by default), then alphabetical, so the
    /// choice is stable. The user can pick another folder.
    public static func ordered(_ names: [String]) -> [String] {
        names.sorted { lhs, rhs in
            let lhsPersonal = lhs.localizedCaseInsensitiveContains("personal")
            let rhsPersonal = rhs.localizedCaseInsensitiveContains("personal")
            if lhsPersonal != rhsPersonal { return lhsPersonal }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    /// The desktop app that does the syncing; a copied file only uploads while it is running.
    public static func syncApp(for provider: CloudProvider) -> (name: String, bundleIdentifier: String) {
        switch provider {
        case .googleDrive: ("Google Drive", "com.google.drivefs")
        case .oneDrive: ("OneDrive", "com.microsoft.OneDrive")
        }
    }
}
