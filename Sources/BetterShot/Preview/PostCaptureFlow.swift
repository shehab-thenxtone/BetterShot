import AppKit
import BetterShotCore

/// What happens after a capture finishes: show the preview popup and carry out its Copy / Save / Pin / Upload
/// actions without ever opening the editor (requirements §3.2, "fast capture" workflow).
@MainActor
final class PostCaptureFlow {
    private let actions: ResultActions
    private let settings: () -> AppSettings
    private let panel = PreviewPanelController()

    /// Opens the annotation editor for an image. Set after construction because the editor hands results back later.
    var openEditor: (@MainActor (CGImage) -> Void)?
    /// Pins an image to the screen and shows its result bar. Pin stays disabled in the popup until this is set.
    var pinImage: (@MainActor (CGImage) -> Void)?

    /// `settings` is read per capture so Preferences changes apply immediately.
    init(actions: ResultActions, settings: @escaping () -> AppSettings) {
        self.actions = actions
        self.settings = settings
    }

    /// Shows the preview popup, or jumps straight into the editor when "open editor automatically" is on.
    func present(_ result: CaptureResult) {
        let image = result.image
        if settings().opensEditorAfterCapture, let openEditor {
            openEditor(image)
            return
        }
        panel.show(
            image: image,
            isPinAvailable: pinImage != nil,
            autoDismissAfter: settings().popupAutoDismissSeconds,
            actions: PreviewActions(
                copy: { [weak self] in
                    self?.actions.copy(image)
                    self?.panel.dismiss()
                },
                save: { [weak self] in
                    if self?.actions.save(image) == true { self?.panel.dismiss() }
                },
                pin: { [weak self] in
                    self?.panel.dismiss()
                    self?.pinImage?(image)
                },
                upload: { [weak self] in
                    if self?.actions.upload(image) == true { self?.panel.dismiss() }
                },
                edit: { [weak self] in
                    self?.panel.dismiss()
                    self?.openEditor?(image)
                }
            )
        )
    }
}
