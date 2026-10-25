import BetterShotCore
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Still capture via ScreenCaptureKit (`SCScreenshotManager`). Never includes BetterShot's own windows.
public struct ScreenCaptureKitCapturer: ScreenCapturer {
    public init() {}

    public func capture(_ request: CaptureRequest) async throws(CaptureError) -> CaptureResult {
        guard ScreenRecordingPermission.isGranted else { throw .permissionDenied }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let image = switch request {
            case .display(let displayID, let scale):
                try await captureDisplay(displayID, area: nil, scale: scale, content: content)
            case .area(let displayID, let rect, let scale):
                try await captureDisplay(displayID, area: rect, scale: scale, content: content)
            case .window(let windowID):
                try await captureWindow(windowID, content: content)
            }
            return CaptureResult(image: image)
        } catch let error as CaptureError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: Private

    private func captureDisplay(
        _ displayID: UInt32, area: CGRect?, scale: CGFloat, content: SCShareableContent
    ) async throws -> CGImage {
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let configuration = SCStreamConfiguration()
        let region = area ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
        configuration.sourceRect = region
        configuration.width = Int((region.width * scale).rounded())
        configuration.height = Int((region.height * scale).rounded())
        configuration.showsCursor = false
        configuration.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private func captureWindow(_ windowID: UInt32, content: SCShareableContent) async throws -> CGImage {
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let info = SCShareableContent.info(for: filter)

        let configuration = SCStreamConfiguration()
        configuration.width = Int((info.contentRect.width * CGFloat(info.pointPixelScale)).rounded())
        configuration.height = Int((info.contentRect.height * CGFloat(info.pointPixelScale)).rounded())
        configuration.ignoreShadowsSingleWindow = false // keep the window's drop shadow
        configuration.showsCursor = false
        configuration.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private static func map(_ error: any Error) -> CaptureError {
        if let streamError = error as? SCStreamError, streamError.code == .userDeclined {
            return .permissionDenied
        }
        return .failed(error.localizedDescription)
    }
}
