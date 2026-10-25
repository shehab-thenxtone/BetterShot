import AppKit
import BetterShotServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var router: AppCommandRouter?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Composition root. Phase 4 replaces the clipboard hand-off with the preview popup.
        let coordinator = CaptureCoordinator(
            capturer: ScreenCaptureKitCapturer(),
            previousAreaStore: UserDefaultsPreviousAreaStore(),
            deliver: { ImageClipboard.copy($0.image) }
        )
        let router = AppCommandRouter(captureCoordinator: coordinator)
        self.router = router
        statusItemController = StatusItemController(handler: router)
    }
}
