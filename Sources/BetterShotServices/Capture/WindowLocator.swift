import BetterShotCore
import CoreGraphics
import Foundation

/// Lists on-screen, normal-level windows for the window picker.
public enum WindowLocator {
    /// Front-to-back, excluding this process's own windows (e.g. the capture overlay).
    public static func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height

        return list.compactMap { entry in
            guard
                (entry[kCGWindowLayer as String] as? Int) == 0,
                (entry[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                let id = entry[kCGWindowNumber as String] as? UInt32,
                let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                bounds.width >= 10, bounds.height >= 10
            else { return nil }

            let owner = entry[kCGWindowOwnerName as String] as? String ?? ""
            let frame = SelectionGeometry.appKitRect(fromWindowListBounds: bounds, primaryScreenHeight: primaryHeight)
            return WindowInfo(id: id, ownerName: owner, frame: frame)
        }
    }
}
