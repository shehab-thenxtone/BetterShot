import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let router = AppCommandRouter()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(handler: router)
    }
}
