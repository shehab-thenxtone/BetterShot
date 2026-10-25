import CoreGraphics

/// An on-screen window the user can pick in Window / All-In-One mode.
public struct WindowInfo: Equatable, Sendable {
    public let id: UInt32
    public let ownerName: String
    /// AppKit global coordinates (bottom-left origin), in points.
    public let frame: CGRect

    public init(id: UInt32, ownerName: String, frame: CGRect) {
        self.id = id
        self.ownerName = ownerName
        self.frame = frame
    }

    /// First window containing `point`; `windows` must be ordered front to back.
    public static func topmost(at point: CGPoint, in windows: [WindowInfo]) -> WindowInfo? {
        windows.first { $0.frame.contains(point) }
    }
}
