import AppKit
import BetterShotAnnotations
import BetterShotCore
import SwiftUI

/// What the toolbar's buttons ask the window to do; the window owns panels and capture.
struct EditorActions {
    let saveAs: @MainActor () -> Void
    let done: @MainActor () -> Void
    let mergeImport: @MainActor () -> Void
    let mergeCapture: @MainActor (CaptureMode) -> Void
}

/// Layout mirrors docs/reference/editor-toolbar.png: crop and merge, the drawing tools, style controls,
/// then Save as… and Done. Crop mode swaps the middle for ratio and apply controls.
struct EditorToolbarView: View {
    let model: EditorModel
    let actions: EditorActions

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 64, height: 1) // room for the window's traffic lights

            if let crop = model.crop {
                cropControls(crop)
            } else {
                editingControls
            }

            Spacer(minLength: 12)

            Button("Save as…") { actions.saveAs() }
            Button("Done") { actions.done() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(WindowDragArea())
        .background(.bar)
    }

    // MARK: Editing

    private var editingControls: some View {
        HStack(spacing: 10) {
            iconButton("crop", label: "Crop") { model.beginCrop() }

            Menu {
                Button("Import Image…") { actions.mergeImport() }
                Divider()
                Button("Capture Area…") { actions.mergeCapture(.area) }
                Button("Capture Window…") { actions.mergeCapture(.window) }
                Button("Capture Fullscreen…") { actions.mergeCapture(.fullscreen) }
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
            .help("Add another image to the canvas")
            .accessibilityLabel("Add image")

            Divider().frame(height: 22)

            HStack(spacing: 2) {
                ForEach(AnnotationTool.allCases, id: \.self) { toolButton($0) }
            }

            Divider().frame(height: 22)

            ColorPicker("Colour", selection: colorBinding, supportsOpacity: true)
                .labelsHidden()
                .help("Colour")

            Menu {
                Picker("Line weight", selection: weightBinding) {
                    ForEach(AnnotationStyle.LineWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            } label: {
                Image(systemName: "lineweight")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
            .help("Line weight")
            .accessibilityLabel("Line weight")

            Menu {
                Picker("Arrow style", selection: arrowBinding) {
                    ForEach(AnnotationStyle.ArrowStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.right")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
            .disabled(!usesArrowStyle)
            .help("Arrow style")
            .accessibilityLabel("Arrow style")
        }
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let isActive = model.tool == tool
        return Button { model.setTool(tool) } label: {
            Image(systemName: tool.symbolName)
                .frame(width: 28, height: 26)
                .background(isActive ? Color.accentColor.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("\(tool.title) (\(tool.defaultKey.uppercased()))")
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 28, height: 26)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: Crop

    private func cropControls(_ crop: CropSession) -> some View {
        HStack(spacing: 10) {
            Button("Cancel") { model.cancelCrop() }
            Picker("Ratio", selection: Binding(get: { crop.ratio }, set: { model.setCropRatio($0) })) {
                ForEach(CropRatio.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
            .help("Crop proportions")
            Button("Apply Crop") { model.applyCrop() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Style bindings

    private var usesArrowStyle: Bool {
        if case .arrow = model.selectedAnnotation?.kind { return true }
        return model.tool == .arrow
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.currentStyle.color.nsColor) },
            set: { newColor in model.applyStyle { $0.updating(color: AnnotationColor(nsColor: NSColor(newColor))) } }
        )
    }

    private var weightBinding: Binding<AnnotationStyle.LineWeight> {
        Binding(get: { model.currentStyle.lineWeight }, set: { weight in model.applyStyle { $0.updating(lineWeight: weight) } })
    }

    private var arrowBinding: Binding<AnnotationStyle.ArrowStyle> {
        Binding(get: { model.currentStyle.arrowStyle }, set: { style in model.applyStyle { $0.updating(arrowStyle: style) } })
    }
}

// MARK: Presentation helpers

extension AnnotationTool {
    var title: String {
        switch self {
        case .select: "Select"
        case .rectangle: "Rectangle"
        case .filledRectangle: "Filled rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .arrow: "Arrow"
        case .text: "Text"
        case .pixelate: "Pixelate"
        case .stepCounter: "Step counter"
        case .marker: "Marker"
        case .pen: "Pen"
        case .textHighlighter: "Text highlighter"
        }
    }

    var symbolName: String {
        switch self {
        case .select: "cursorarrow"
        case .rectangle: "rectangle"
        case .filledRectangle: "rectangle.fill"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .pixelate: "square.grid.3x3.fill"
        case .stepCounter: "1.circle.fill"
        case .marker: "paintbrush.pointed"
        case .pen: "pencil.tip"
        case .textHighlighter: "highlighter"
        }
    }
}

private extension AnnotationStyle.ArrowStyle {
    var label: String {
        switch self {
        case .solid: "Solid head"
        case .open: "Open head"
        }
    }
}

private extension AnnotationColor {
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? .black
        self.init(red: converted.redComponent, green: converted.greenComponent, blue: converted.blueComponent, alpha: converted.alphaComponent)
    }
}
