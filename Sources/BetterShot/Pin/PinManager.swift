import AppKit

/// Creates pinned-image windows and keeps them alive until they're closed.
@MainActor
final class PinManager {
    private let actions: ResultActions
    private var controllers: [PinnedImageWindowController] = []

    /// Opens the editor for a pinned image ("Open in Editor" in its context menu).
    var openEditor: (@MainActor (CGImage) -> Void)?

    init(actions: ResultActions) {
        self.actions = actions
    }

    /// Pins `image` and returns its controller. `onClose` runs when that pin is closed, however that happens.
    @discardableResult
    func pin(
        image: CGImage,
        onClose: @escaping @MainActor (PinnedImageWindowController) -> Void = { _ in }
    ) -> PinnedImageWindowController {
        let controller = PinnedImageWindowController(
            image: image,
            pointScale: NSScreen.underCursor?.backingScaleFactor ?? 2,
            slot: controllers.count,
            actions: actions,
            openEditor: { [weak self] in self?.openEditor?($0) }
        )
        controller.onClose = { [weak self] closed in
            self?.controllers.removeAll { $0 === closed }
            onClose(closed)
        }
        controllers.append(controller)
        controller.show()
        return controller
    }
}
