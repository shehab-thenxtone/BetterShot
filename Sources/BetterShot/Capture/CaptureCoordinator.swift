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

    /// Handles "Capture Text (OCR)" results: set after construction, since the OCR flow is built separately.
    var recognizeText: (@MainActor (CGImage) async -> Void)?

    /// Self-Timer hooks: the on-screen countdown (true = it finished) and how long it runs. Set after construction.
    var countdown: (@MainActor (Int) async -> Bool)?
    var selfTimerSeconds: @MainActor () -> Int = { SelfTimerDelay.five.seconds }

    /// A normal capture: select, capture, then hand the result to the post-capture flow.
    /// Capture Text instead sends the image to text recognition and never shows the preview popup.
    func start(_ mode: CaptureMode) async {
        guard let result = await capture(mode) else { return }
        if mode == .ocr {
            await recognizeText?(result.image)
        } else {
            deliver(result)
        }
    }

    /// Captures without delivering, for callers that use the image themselves (the editor's Merge tool).
    func captureImage(_ mode: CaptureMode) async -> CaptureResult? {
        await capture(mode)
    }

    private func capture(_ mode: CaptureMode) async -> CaptureResult? {
        guard !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }

        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request()
            CaptureAlerts.presentPermissionDenied()
            return nil
        }
        guard let request = await resolveRequest(for: mode) else { return nil }

        do {
            let result = try await capturer.capture(request)
            if case .area(let displayID, let rect, _) = request {
                previousAreaStore.save(PreviousArea(displayID: displayID, rect: rect))
            }
            return result
        } catch {
            logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            CaptureAlerts.present(error)
            return nil
        }
    }

    // MARK: Request resolution

    private func resolveRequest(for mode: CaptureMode) async -> CaptureRequest? {
        switch mode {
        case .fullscreen:
            return NSScreen.underCursor.map(displayRequest(for:))
        case .area, .ocr: // Capture Text selects a region exactly like Capture Area
            return request(for: await overlay.run(mode: .area))
        case .window:
            return request(for: await overlay.run(mode: .window))
        case .allInOne:
            return request(for: await overlay.run(mode: .allInOne))
        case .selfTimer:
            // Choose what to capture first, then count down, so there's time to open a menu inside the chosen region.
            guard let request = request(for: await overlay.run(mode: .allInOne)) else { return nil }
            guard await countdown?(selfTimerSeconds()) ?? true else { return nil }
            return request
        case .previousArea:
            return await previousAreaRequest()
        case .scrolling, .recordScreen:
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
