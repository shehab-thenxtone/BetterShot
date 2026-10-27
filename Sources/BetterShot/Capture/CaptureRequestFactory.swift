import AppKit
import BetterShotCore

/// Turns what the user picked on the selection overlay into a capture request. Shared by screenshots and recording.
@MainActor
enum CaptureRequestFactory {
    static func request(for outcome: SelectionOutcome) -> CaptureRequest? {
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

    static func displayRequest(for screen: NSScreen) -> CaptureRequest {
        .display(displayID: screen.displayID, scale: screen.backingScaleFactor)
    }
}
