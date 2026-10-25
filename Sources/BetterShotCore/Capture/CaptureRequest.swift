import CoreGraphics
import Foundation

/// What to capture, expressed without any ScreenCaptureKit types.
public enum CaptureRequest: Equatable, Sendable {
    case display(displayID: UInt32, scale: CGFloat)
    /// `rect` is display-local, top-left origin, in points.
    case area(displayID: UInt32, rect: CGRect, scale: CGFloat)
    /// Output scale comes from the window's display; ScreenCaptureKit reports it.
    case window(windowID: UInt32)
}

/// A finished still capture, ready for the post-capture flow.
public struct CaptureResult: @unchecked Sendable { // CGImage is immutable
    public let image: CGImage
    public let capturedAt: Date

    public init(image: CGImage, capturedAt: Date = Date()) {
        self.image = image
        self.capturedAt = capturedAt
    }
}

public enum CaptureError: Error, Equatable, LocalizedError, Sendable {
    case permissionDenied
    case displayNotFound
    case windowNotFound
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "BetterShot needs Screen Recording permission to capture the screen."
        case .displayNotFound: "The display to capture is no longer available."
        case .windowNotFound: "The window to capture is no longer available."
        case .failed(let reason): "Capture failed: \(reason)"
        }
    }
}

/// The last area the user captured, so "Capture Previous Area" can repeat it (requirements §3.1 item 3).
public struct PreviousArea: Equatable, Codable, Sendable {
    public let displayID: UInt32
    /// Display-local, top-left origin, in points.
    public let rect: CGRect

    public init(displayID: UInt32, rect: CGRect) {
        self.displayID = displayID
        self.rect = rect
    }
}

/// Implemented by the ScreenCaptureKit service; faked in tests.
public protocol ScreenCapturer: Sendable {
    func capture(_ request: CaptureRequest) async throws(CaptureError) -> CaptureResult
}

public protocol PreviousAreaStoring: Sendable {
    func load() -> PreviousArea?
    func save(_ area: PreviousArea)
}
