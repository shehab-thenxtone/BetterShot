import ApplicationServices

/// Accessibility (TCC) permission, which macOS requires before an app may post scroll events to other apps.
/// Scrolling Capture needs it; nothing else in BetterShot does.
public enum AccessibilityPermission {
    public static var isGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt the first time; afterwards it only reports the current state.
    @discardableResult
    public static func request() -> Bool {
        // The documented key for kAXTrustedCheckOptionPrompt, spelled out because the C global isn't concurrency-safe.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
