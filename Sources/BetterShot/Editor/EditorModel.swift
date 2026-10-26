import AppKit
import BetterShotAnnotations
import BetterShotCore
import BetterShotServices
import Observation

enum CropRatio: CaseIterable, Hashable {
    case free, square, fourThree, sixteenNine, threeTwo

    /// Width / height, or nil for a free-form crop.
    var ratio: CGFloat? {
        switch self {
        case .free: nil
        case .square: 1
        case .fourThree: 4 / 3
        case .sixteenNine: 16 / 9
        case .threeTwo: 3 / 2
        }
    }

    var label: String {
        switch self {
        case .free: "Free"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .sixteenNine: "16:9"
        case .threeTwo: "3:2"
        }
    }
}

struct CropSession: Equatable {
    var rect: CGRect // document points
    var ratio: CropRatio
}

/// All editor state the UI reads and the canvas mutates: the undoable image + annotations, the active tool,
/// the selection and any crop in progress. Every committed edit goes through `history`.
@MainActor
@Observable
final class EditorModel {
    private(set) var history: UndoHistory<EditorState>
    private(set) var tool: AnnotationTool = .arrow
    private(set) var toolStyles: ToolStyles
    private(set) var selectedID: UUID?
    private(set) var crop: CropSession?

    @ObservationIgnored private let stylesStore: UserDefaultsToolStylesStore
    @ObservationIgnored private let ocr: any OCRProvider
    /// Recognition results per base image. The image is kept alongside so its identity can't be reused.
    @ObservationIgnored private var recognitions: [ObjectIdentifier: (image: BaseImage, task: Task<[RecognizedLine], Never>)] = [:]
    /// The AppKit canvas isn't observation-aware; it redraws through this.
    @ObservationIgnored var onChange: (() -> Void)?
    /// Lets toolbar actions hand keyboard focus back to the canvas so tool shortcuts keep working.
    @ObservationIgnored var focusCanvas: (() -> Void)?

    init(image: CGImage, pointScale: CGFloat, stylesStore: UserDefaultsToolStylesStore, ocr: any OCRProvider) {
        history = UndoHistory(initial: EditorState(image: image, pointScale: pointScale))
        toolStyles = stylesStore.load()
        self.stylesStore = stylesStore
        self.ocr = ocr
    }

    // MARK: Reading

    var state: EditorState { history.present }
    var document: AnnotationDocument { state.document }
    var pointScale: CGFloat { state.pointScale }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    var selectedAnnotation: Annotation? {
        selectedID.flatMap { document.annotation(id: $0) }
    }

    /// Style shown in the toolbar: the selection's, otherwise the active tool's remembered style.
    var currentStyle: AnnotationStyle {
        selectedAnnotation?.style ?? toolStyles.style(for: tool)
    }

    /// Text size follows the line-weight control (there is no separate font-size control in the reference toolbar).
    static func fontSize(for weight: AnnotationStyle.LineWeight) -> CGFloat {
        switch weight {
        case .thin: 14
        case .medium: 18
        case .thick: 28
        }
    }

    func flattened() -> CGImage? { state.flattened() }

    // MARK: Tools and selection

    func setTool(_ newTool: AnnotationTool) {
        crop = nil
        tool = newTool
        if newTool != .select { selectedID = nil }
        if newTool == .textHighlighter { prepareTextRecognition() } // so the first highlight snaps instantly
        changed()
        focusCanvas?()
    }

    func select(_ id: UUID?) {
        guard selectedID != id else { return }
        selectedID = id
        changed()
    }

    // MARK: Committing edits

    func commit(_ document: AnnotationDocument) {
        history = history.committing(state.with(document: document))
        pruneSelection()
        changed()
    }

    func addAnnotation(_ kind: AnnotationKind) {
        commit(document.adding(kind, style: toolStyles.style(for: tool)))
    }

    func addStep(at point: CGPoint) {
        commit(document.addingStep(at: point, style: toolStyles.style(for: .stepCounter)))
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        commit(document.removing(id: id))
    }

    func undo() {
        crop = nil
        history = history.undone()
        pruneSelection()
        changed()
    }

    func redo() {
        crop = nil
        history = history.redone()
        pruneSelection()
        changed()
    }

    /// Applies a style change to the selection (as one undo step) and remembers it for the active tool.
    func applyStyle(_ transform: (AnnotationStyle) -> AnnotationStyle) {
        let style = transform(currentStyle)
        if let id = selectedID {
            commit(document.restyling(id: id, with: style))
        }
        if tool != .select {
            toolStyles = toolStyles.setting(style, for: tool)
            stylesStore.save(toolStyles)
        }
        changed()
    }

    // MARK: Crop

    func beginCrop() {
        selectedID = nil
        let size = document.canvasSize
        let initial = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.08)
        crop = CropSession(rect: initial, ratio: .free)
        changed()
    }

    func updateCrop(rect: CGRect) {
        guard var session = crop else { return }
        session.rect = rect
        crop = session
        changed()
    }

    func setCropRatio(_ ratio: CropRatio) {
        guard var session = crop else { return }
        session.ratio = ratio
        if let target = ratio.ratio { session.rect = Self.fit(session.rect, toRatio: target) }
        crop = session
        changed()
    }

    func applyCrop() {
        defer { crop = nil; changed(); focusCanvas?() }
        guard let session = crop, let cropped = state.cropped(to: session.rect) else { return }
        history = history.committing(cropped)
        selectedID = nil
    }

    func cancelCrop() {
        crop = nil
        changed()
        focusCanvas?()
    }

    // MARK: Text highlighter (OCR snapping)

    /// Starts recognizing the current image in the background.
    func prepareTextRecognition() {
        _ = recognitionTask(for: state.baseImage)
    }

    /// Adds a highlight for a drag over `selection` (document points): one even band per covered line of text
    /// when text is found there, otherwise the plain rectangle. One undo step either way.
    func addTextHighlight(selection: CGRect) async {
        let base = state.baseImage
        let lines = await recognitionTask(for: base).value
        guard state.baseImage == base else { return } // cropped, merged or undone while recognizing

        let snapped = TextHighlightSnapper.snap(selection: selection, lines: lines.map { $0.scaled(by: 1 / pointScale) })
        let rects = snapped.isEmpty ? [selection] : snapped
        commit(document.adding(contentsOf: rects.map { .textHighlight($0) }, style: toolStyles.style(for: .textHighlighter)))
    }

    private func recognitionTask(for base: BaseImage) -> Task<[RecognizedLine], Never> {
        let key = ObjectIdentifier(base)
        if let existing = recognitions[key] { return existing.task }

        if recognitions.count >= 4 { recognitions.removeAll() } // old images (before crop/merge) aren't coming back often
        let provider = ocr
        let image = base.cgImage
        let task = Task { (try? await provider.recognize(in: image, languages: [.english])) ?? [] }
        recognitions[key] = (base, task)
        return task
    }

    // MARK: Merge

    /// Adds `image` to the right of the current image (requirements §3.3 "Merge tool").
    func merge(_ image: CGImage) {
        guard let merged = state.appendingRight(image) else { return }
        history = history.committing(merged)
        selectedID = nil
        crop = nil
        changed()
    }

    // MARK: Private

    private func pruneSelection() {
        if let id = selectedID, document.annotation(id: id) == nil { selectedID = nil }
    }

    private func changed() {
        onChange?()
    }

    /// Largest rect with the given width/height ratio inside `rect`, sharing its centre.
    private static func fit(_ rect: CGRect, toRatio ratio: CGFloat) -> CGRect {
        var width = rect.width
        var height = rect.height
        if width / height > ratio { width = height * ratio } else { height = width / ratio }
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }
}
