import AppKit
import BetterShotCore
import BetterShotServices

/// Opens editor windows and keeps them alive until they close.
@MainActor
final class EditorPresenter {
    private let stylesStore: UserDefaultsToolStylesStore
    private let folderStore: any SaveFolderStoring
    private let settings: () -> AppSettings
    private var controllers: [EditorWindowController] = []

    /// Called with the flattened image when the user presses Done.
    var onDone: (@MainActor (CGImage) -> Void)?
    /// Runs one capture for the Merge tool; nil if it was cancelled or failed.
    var captureForMerge: (@MainActor (CaptureMode) async -> CGImage?)?

    init(stylesStore: UserDefaultsToolStylesStore, folderStore: any SaveFolderStoring, settings: @escaping () -> AppSettings) {
        self.stylesStore = stylesStore
        self.folderStore = folderStore
        self.settings = settings
    }

    /// `pointScale` defaults to the display's backing scale so Retina captures open at their natural size.
    func open(image: CGImage, pointScale: CGFloat? = nil) {
        let controller = EditorWindowController(
            image: image,
            pointScale: pointScale ?? NSScreen.underCursor?.backingScaleFactor ?? 2,
            stylesStore: stylesStore,
            folderStore: folderStore,
            settings: settings,
            captureForMerge: { [weak self] mode in await self?.captureForMerge?(mode) },
            onDone: { [weak self] image in self?.onDone?(image) }
        )
        controller.onClose = { [weak self] closed in self?.controllers.removeAll { $0 === closed } }
        controllers.append(controller)
        controller.show()
    }
}
