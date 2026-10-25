import CoreGraphics

/// Screen Recording (TCC) permission, required by ScreenCaptureKit.
public enum ScreenRecordingPermission {
    public static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt the first time; afterwards it only reports the current state.
    @discardableResult
    public static func request() -> Bool { CGRequestScreenCaptureAccess() }
}
