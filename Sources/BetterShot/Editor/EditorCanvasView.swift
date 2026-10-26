import AppKit
import BetterShotAnnotations
import SwiftUI

/// SwiftUI bridge for the AppKit canvas.
struct EditorCanvas: NSViewRepresentable {
    let model: EditorModel

    func makeNSView(context: Context) -> EditorCanvasView {
        EditorCanvasView(model: model)
    }

    func updateNSView(_ view: EditorCanvasView, context: Context) {}
}

/// Shows the image with its annotations and turns mouse/keyboard input into editor edits.
/// Geometry rules live in `BetterShotAnnotations` (`ShapeGesture`, `ResizeGeometry`, `Viewport`); this class only
/// forwards points and draws feedback.
@MainActor
final class EditorCanvasView: NSView, NSTextFieldDelegate, NSMenuItemValidation {
    private enum Interaction {
        case none
        case creating(start: CGPoint, current: CGPoint)
        case freehand(points: [CGPoint])
        case moving(id: UUID, start: CGPoint, original: AnnotationDocument)
        case resizing(id: UUID, handle: ResizeHandle, original: AnnotationDocument, originalBounds: CGRect)
        case movingLineEnd(id: UUID, isStart: Bool, original: AnnotationDocument)
        case cropResizing(ResizeHandle)
        case cropMoving(start: CGPoint, originalRect: CGRect)
    }

    private enum EditHandle {
        case resize(ResizeHandle)
        case lineEnd(isStart: Bool)
    }

    private struct TextEditSession {
        let field: NSTextField
        let origin: CGPoint
        let fontSize: CGFloat
        let style: AnnotationStyle
        let existing: Annotation?
    }

    private static let viewPadding: CGFloat = 24
    private static let handleHitRadius: CGFloat = 9
    private static let handleSize: CGFloat = 8
    private static let minimumCropSide: CGFloat = 16

    private let model: EditorModel
    private var interaction = Interaction.none
    /// Document shown instead of the model's while an edit is being dragged; committed on mouse-up.
    private var draftDocument: AnnotationDocument?
    private var textEditor: TextEditSession?
    private var shiftDown = false

    init(model: EditorModel) {
        self.model = model
        super.init(frame: .zero)
        model.onChange = { [weak self] in self?.modelChanged() }
        model.focusCanvas = { [weak self] in
            guard let self, self.textEditor == nil else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    private var viewport: Viewport {
        Viewport(canvasSize: model.document.canvasSize, viewSize: bounds.size, padding: Self.viewPadding)
    }

    private var canvasBounds: CGRect { CGRect(origin: .zero, size: model.document.canvasSize) }

    private func modelChanged() {
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        let cursor: NSCursor = switch model.tool {
        case .select: .arrow
        case .text: .iBeam
        default: .crosshair
        }
        addCursorRect(viewport.canvasRectInView, cursor: model.crop == nil ? cursor : .arrow)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        bounds.fill()

        let viewport = self.viewport
        let canvasRect = viewport.canvasRectInView
        if let image = AnnotationRenderer.flatten(model.state.baseImage.cgImage, with: renderedDocument()) {
            NSImage(cgImage: image, size: canvasRect.size).draw(
                in: canvasRect, from: .zero, operation: .sourceOver, fraction: 1,
                respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        if model.crop == nil { drawSelection(viewport) } else { drawCrop(viewport) }
    }

    /// The model's document plus whatever is being dragged or drawn right now.
    private func renderedDocument() -> AnnotationDocument {
        let base = draftDocument ?? model.document
        let style = model.toolStyles.style(for: model.tool)
        switch interaction {
        case .creating(let start, let current):
            guard let kind = ShapeGesture.kind(for: model.tool, from: start, to: current, constrained: shiftDown) else { return base }
            return base.adding(kind, style: style)
        case .freehand(let points):
            return base.adding(model.tool == .pen ? .pen(points: points) : .marker(points: points), style: style)
        default:
            return base
        }
    }

    private func drawSelection(_ viewport: Viewport) {
        guard let id = model.selectedID, let annotation = (draftDocument ?? model.document).annotation(id: id) else { return }
        let accent = NSColor.controlAccentColor

        switch annotation.kind {
        case .line(let from, let to), .arrow(let from, let to):
            for point in [from, to] { drawHandle(at: viewport.toView(point), round: true) }
        case .stepCounter:
            outline(viewport.toView(annotation.kind.bounds).insetBy(dx: -2, dy: -2), color: accent)
        default:
            let rect = viewport.toView(annotation.kind.bounds)
            outline(rect, color: accent)
            for point in ResizeGeometry.handlePositions(of: rect).values { drawHandle(at: point, round: false) }
        }
    }

    private func outline(_ rect: CGRect, color: NSColor) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1
        path.setLineDash([4, 3], count: 2, phase: 0)
        color.setStroke()
        path.stroke()
    }

    private func drawHandle(at point: CGPoint, round: Bool) {
        let rect = CGRect(x: point.x - Self.handleSize / 2, y: point.y - Self.handleSize / 2, width: Self.handleSize, height: Self.handleSize)
        let path = round ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
        NSColor.white.setFill()
        path.fill()
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawCrop(_ viewport: Viewport) {
        guard let session = model.crop else { return }
        let rect = viewport.toView(session.rect)

        let dim = NSBezierPath(rect: viewport.canvasRectInView)
        dim.append(NSBezierPath(rect: rect))
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.5).setFill()
        dim.fill()

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        border.stroke()

        let grid = NSBezierPath()
        for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
            grid.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
            grid.line(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
            grid.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
            grid.line(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
        }
        NSColor.white.withAlphaComponent(0.4).setStroke()
        grid.lineWidth = 0.5
        grid.stroke()

        for point in ResizeGeometry.handlePositions(of: rect).values { drawHandle(at: point, round: false) }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self) // also commits any text being edited
        shiftDown = event.modifierFlags.contains(.shift)
        let viewPoint = convert(event.locationInWindow, from: nil)
        let point = viewport.toCanvas(viewPoint)

        if model.crop != nil {
            beginCropInteraction(viewPoint: viewPoint, point: point)
        } else {
            switch model.tool {
            case .select:
                beginSelection(viewPoint: viewPoint, point: point, clickCount: event.clickCount)
            case .text:
                if canvasBounds.contains(point) { beginTextEditing(at: point, editing: nil) }
            case .stepCounter:
                if canvasBounds.contains(point) { model.addStep(at: point) }
            case .pen, .marker:
                if canvasBounds.contains(point) { interaction = .freehand(points: [point]) }
            default:
                if canvasBounds.contains(point) { interaction = .creating(start: point, current: point) }
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        shiftDown = event.modifierFlags.contains(.shift)
        let point = viewport.toCanvas(convert(event.locationInWindow, from: nil))

        switch interaction {
        case .none:
            break
        case .creating(let start, _):
            interaction = .creating(start: start, current: clamped(point))
        case .freehand(var points):
            let next = clamped(point)
            if let last = points.last, hypot(next.x - last.x, next.y - last.y) < 1 { break }
            points.append(next)
            interaction = .freehand(points: points)
        case .moving(let id, let start, let original):
            draftDocument = original.moving(id: id, by: CGSize(width: point.x - start.x, height: point.y - start.y))
        case .resizing(let id, let handle, let original, let originalBounds):
            let ratio = shiftDown && originalBounds.height > 0 ? originalBounds.width / originalBounds.height : nil
            let resized = ResizeGeometry.resize(originalBounds, dragging: handle, to: point, aspectRatio: ratio)
            draftDocument = original.resizing(id: id, to: resized)
        case .movingLineEnd(let id, let isStart, let original):
            draftDocument = original.replacingKind(of: id, with: movedEnd(of: original.annotation(id: id)?.kind, isStart: isStart, to: point))
        case .cropResizing(let handle):
            guard let session = model.crop else { break }
            model.updateCrop(rect: ResizeGeometry.resize(
                session.rect, dragging: handle, to: point, aspectRatio: session.ratio.ratio,
                within: canvasBounds, minimumSide: Self.minimumCropSide
            ))
        case .cropMoving(let start, let originalRect):
            let moved = originalRect.offsetBy(dx: point.x - start.x, dy: point.y - start.y)
            let x = min(max(moved.minX, 0), canvasBounds.width - moved.width)
            let y = min(max(moved.minY, 0), canvasBounds.height - moved.height)
            model.updateCrop(rect: CGRect(x: x, y: y, width: moved.width, height: moved.height))
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        shiftDown = event.modifierFlags.contains(.shift)
        defer {
            interaction = .none
            draftDocument = nil
            needsDisplay = true
        }

        switch interaction {
        case .creating(let start, let current):
            if let kind = ShapeGesture.kind(for: model.tool, from: start, to: current, constrained: shiftDown) {
                model.addAnnotation(kind)
            }
        case .freehand(let points):
            model.addAnnotation(model.tool == .pen ? .pen(points: points) : .marker(points: points))
        case .moving, .resizing, .movingLineEnd:
            if let draft = draftDocument { model.commit(draft) }
        case .none, .cropResizing, .cropMoving:
            break
        }
    }

    override func flagsChanged(with event: NSEvent) {
        shiftDown = event.modifierFlags.contains(.shift)
        if case .none = interaction { return }
        needsDisplay = true
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), canvasBounds.width), y: min(max(point.y, 0), canvasBounds.height))
    }

    // MARK: Selecting and editing

    private func beginSelection(viewPoint: CGPoint, point: CGPoint, clickCount: Int) {
        let document = model.document
        if let selected = model.selectedAnnotation, let handle = editHandle(for: selected, atView: viewPoint) {
            switch handle {
            case .resize(let resizeHandle):
                interaction = .resizing(id: selected.id, handle: resizeHandle, original: document, originalBounds: selected.kind.bounds)
            case .lineEnd(let isStart):
                interaction = .movingLineEnd(id: selected.id, isStart: isStart, original: document)
            }
            return
        }

        let tolerance = 6 / viewport.scale
        guard let hit = document.topmostAnnotation(at: point, tolerance: tolerance) else {
            model.select(nil)
            return
        }
        model.select(hit.id)
        if clickCount == 2, case .text(_, let origin, _) = hit.kind {
            beginTextEditing(at: origin, editing: hit)
        } else {
            interaction = .moving(id: hit.id, start: point, original: document)
        }
    }

    private func editHandle(for annotation: Annotation, atView point: CGPoint) -> EditHandle? {
        switch annotation.kind {
        case .line(let from, let to), .arrow(let from, let to):
            let start = viewport.toView(from), end = viewport.toView(to)
            if hypot(point.x - start.x, point.y - start.y) <= Self.handleHitRadius { return .lineEnd(isStart: true) }
            if hypot(point.x - end.x, point.y - end.y) <= Self.handleHitRadius { return .lineEnd(isStart: false) }
            return nil
        case .stepCounter:
            return nil
        default:
            return ResizeGeometry.handle(at: point, of: viewport.toView(annotation.kind.bounds), tolerance: Self.handleHitRadius)
                .map(EditHandle.resize)
        }
    }

    private func movedEnd(of kind: AnnotationKind?, isStart: Bool, to point: CGPoint) -> AnnotationKind {
        switch kind {
        case .line(let from, let to): .line(from: isStart ? point : from, to: isStart ? to : point)
        case .arrow(let from, let to): .arrow(from: isStart ? point : from, to: isStart ? to : point)
        default: kind ?? .line(from: point, to: point)
        }
    }

    private func beginCropInteraction(viewPoint: CGPoint, point: CGPoint) {
        guard let session = model.crop else { return }
        if let handle = ResizeGeometry.handle(at: viewPoint, of: viewport.toView(session.rect), tolerance: Self.handleHitRadius + 2) {
            interaction = .cropResizing(handle)
        } else if session.rect.contains(point) {
            interaction = .cropMoving(start: point, originalRect: session.rect)
        }
    }

    // MARK: Text editing

    private func beginTextEditing(at point: CGPoint, editing existing: Annotation?) {
        commitTextEditing()

        var text = ""
        var origin = point
        var fontSize: CGFloat
        let style = existing?.style ?? model.toolStyles.style(for: .text)
        fontSize = EditorModel.fontSize(for: style.lineWeight)
        if let existing, case .text(let string, let existingOrigin, let existingSize) = existing.kind {
            text = string
            origin = existingOrigin
            fontSize = existingSize
        }

        let scale = viewport.scale
        let field = NSTextField(string: text)
        field.font = NSFont(name: "HelveticaNeue", size: fontSize * scale) ?? .systemFont(ofSize: fontSize * scale)
        field.textColor = NSColor(srgbRed: style.color.red, green: style.color.green, blue: style.color.blue, alpha: style.color.alpha)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderString = "Type text"
        field.lineBreakMode = .byWordWrapping
        field.cell?.usesSingleLineMode = false
        field.delegate = self

        let viewOrigin = viewport.toView(origin)
        field.frame = CGRect(x: viewOrigin.x, y: viewOrigin.y, width: max(160, bounds.maxX - viewOrigin.x - 8), height: fontSize * scale * 1.4)
        addSubview(field)
        window?.makeFirstResponder(field)

        textEditor = TextEditSession(field: field, origin: origin, fontSize: fontSize, style: style, existing: existing)
        if let existing { draftDocument = model.document.removing(id: existing.id) } // hide the original while editing
        needsDisplay = true
    }

    private func commitTextEditing() {
        finishTextEditing(commit: true)
    }

    private func finishTextEditing(commit: Bool) {
        guard let session = textEditor else { return }
        textEditor = nil // clear first: removing the field triggers more delegate callbacks
        let text = session.field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        session.field.removeFromSuperview()
        draftDocument = nil
        window?.makeFirstResponder(self)

        if commit {
            let document = model.document
            if let existing = session.existing {
                if text.isEmpty {
                    model.commit(document.removing(id: existing.id))
                } else {
                    model.commit(document.replacingKind(of: existing.id, with: .text(text, origin: session.origin, fontSize: session.fontSize)))
                }
            } else if !text.isEmpty {
                model.commit(document.adding(.text(text, origin: session.origin, fontSize: session.fontSize), style: session.style))
            }
        }
        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
                textView.insertNewlineIgnoringFieldEditor(nil) // ⌥Return starts a new line
            } else {
                finishTextEditing(commit: true)
            }
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            finishTextEditing(commit: false)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        finishTextEditing(commit: true) // focus moved elsewhere
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        guard textEditor == nil else { return super.keyDown(with: event) }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1

        switch event.keyCode {
        case 53: // Esc
            if model.crop != nil { model.cancelCrop() } else { model.select(nil) }
        case 36, 76: // Return / Enter
            if model.crop != nil { model.applyCrop() }
        case 51, 117: // Delete / Forward Delete
            model.deleteSelected()
        case 123: nudgeSelection(dx: -step, dy: 0)
        case 124: nudgeSelection(dx: step, dy: 0)
        case 125: nudgeSelection(dx: 0, dy: step)
        case 126: nudgeSelection(dx: 0, dy: -step)
        default:
            let isPlainKey = event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            if isPlainKey, let key = event.charactersIgnoringModifiers, let tool = AnnotationTool.tool(forKey: key) {
                model.setTool(tool)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard let id = model.selectedID, model.crop == nil else { return }
        model.commit(model.document.moving(id: id, by: CGSize(width: dx, height: dy)))
    }

    // MARK: Edit menu actions (routed through the responder chain)

    @objc func undo(_ sender: Any?) {
        commitTextEditing()
        model.undo()
    }

    @objc func redo(_ sender: Any?) {
        commitTextEditing()
        model.redo()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): model.canUndo
        case #selector(redo(_:)): model.canRedo
        default: true
        }
    }
}
