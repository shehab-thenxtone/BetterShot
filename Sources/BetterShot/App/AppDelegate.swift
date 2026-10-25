import AppKit
import BetterShotCore
import BetterShotServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var router: AppCommandRouter?
    private var postCaptureFlow: PostCaptureFlow?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Composition root. Settings are the defaults until Preferences (phase 5) can persist them.
        let flow = PostCaptureFlow(folderStore: UserDefaultsSaveFolderStore(), settings: { AppSettings() })
        postCaptureFlow = flow
        let coordinator = CaptureCoordinator(
            capturer: ScreenCaptureKitCapturer(),
            previousAreaStore: UserDefaultsPreviousAreaStore(),
            deliver: { flow.present($0) }
        )
        let router = AppCommandRouter(captureCoordinator: coordinator)
        self.router = router
        statusItemController = StatusItemController(handler: router)
    }
}
