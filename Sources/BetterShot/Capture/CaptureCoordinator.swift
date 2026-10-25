import AppKit
import BetterShotCore
import BetterShotServices
import OSLog

/// Runs one capture end to end: permission → (overlay) → ScreenCaptureKit → hand-off to `deliver`.
/// `deliver` is the post-capture hook; phase 3 copies to the clipboard, phase 4 swaps in the preview popup.
@MainActor
final class CaptureCoordinator {
    private let capturer: any ScreenCapturer
    private let previousAreaStore: any PreviousAreaStoring
    private let deliver: @MainActor (CaptureResult) -> Void
    private let overlay = SelectionOverlayController()
    private let logger = Logger(subsystem: "com.bettershot.app", category: "capture")
    private var isBusy = false

    init(
        capturer: any ScreenCapturer,
        previousAreaStore: any PreviousAreaStoring,
        deliver: @escaping @MainActor (CaptureResult) -> Void
    ) {
        self.capturer = capturer
        self.previousAreaStore = previousAreaStore
        self.deliver = deliver
    }

    func start(_ mode: CaptureMode) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request()
            CaptureAlerts.presentPermissionDenied()
            return
        }
        guard let request = await resolveRequest(for: mode) else { return }

        do {
            let result = try await capturer.capture(request)
            if case .area(let displayID, let rect, _) = request {
                previousAreaStore.save(PreviousArea(displayID: displayID, rect: rect))
            }
            deliver(result)
        } catch {
            logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            CaptureAlerts.present(error)
        }
    }

    // MARK: Request resolution

    private func resolveRequest(for mode: CaptureMode) async -> CaptureRequest? {
        switch mode {
        case .fullscreen:
            return NSScreen.underCursor.map(displayRequest(for:))
        case .area:
            return request(for: await overlay.run(mode: .area))
        case .window:
            return request(for: await overlay.run(mode: .window))
        case .allInOne:
            return request(for: await overlay.run(mode: .allInOne))
        case .previousArea:
            return await previousAreaRequest()
        case .selfTimer, .scrolling, .ocr, .recordScreen:
            logger.notice("Not implemented yet: \(mode.rawValue, privacy: .public)")
            return nil
        }
    }

    /// Repeats the last area; if there is none (or its display is gone) the user draws a new one.
    private func previousAreaRequest() async -> CaptureRequest? {
        if let area = previousAreaStore.load(), let screen = NSScreen.screen(withDisplayID: area.displayID) {
            return .area(displayID: area.displayID, rect: area.rect, scale: screen.backingScaleFactor)
        }
        return request(for: await overlay.run(mode: .area))
    }

    private func request(for outcome: SelectionOutcome) -> CaptureRequest? {
        switch outcome {
        case .cancelled:
            nil
        case .fullscreen(let displayID):
            NSScreen.screen(withDisplayID: displayID).map(displayRequest(for:))
        case .window(let window):
            .window(windowID: window.id)
        case .area(let displayID, let globalRect):
            NSScreen.screen(withDisplayID: displayID).map { screen in
                .area(
                    displayID: displayID,
                    rect: SelectionGeometry.displayLocalRect(fromGlobal: globalRect, screenFrame: screen.frame),
                    scale: screen.backingScaleFactor
                )
            }
        }
    }

    private func displayRequest(for screen: NSScreen) -> CaptureRequest {
        .display(displayID: screen.displayID, scale: screen.backingScaleFactor)
    }
}
