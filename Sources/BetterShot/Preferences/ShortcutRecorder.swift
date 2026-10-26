import AppKit
import BetterShotCore
import BetterShotServices
import SwiftUI

/// Click, then press a key combination to record it. Esc cancels. Reads the physical key so ⇧4 records as "4".
struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: KeyShortcut?
    let title: String
    let onRecord: (KeyShortcut) -> Void
    let onReject: (String) -> Void

    func makeNSView(context: Context) -> RecorderField {
        RecorderField()
    }

    func updateNSView(_ field: RecorderField, context: Context) {
        field.shortcut = shortcut
        field.fieldTitle = title
        field.onRecord = onRecord
        field.onReject = onReject
    }
}

final class RecorderField: NSView {
    var shortcut: KeyShortcut? { didSet { refresh() } }
    var fieldTitle = "" { didSet { refresh() } }
    var onRecord: ((KeyShortcut) -> Void)?
    var onReject: ((String) -> Void)?

    private var isRecording = false { didSet { refresh() } }

    private static let escapeKeyCode: UInt16 = 53

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        handle(event)
    }

    /// While recording, swallow key equivalents (e.g. ⌘4) so they're recorded instead of triggering menus.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handle(event)
        return true
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            isRecording = false
            return
        }
        guard let key = KeyCodeMap.key(forKeyCode: UInt32(event.keyCode)) else {
            onReject?("That key can't be used in a shortcut.")
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: KeyShortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }

        isRecording = false
        onRecord?(KeyShortcut(key: key, modifiers: modifiers))
    }

    // MARK: Drawing

    private var displayText: String {
        if isRecording { return "Type shortcut…" }
        return shortcut?.displayString ?? "Click to record"
    }

    private func refresh() {
        setAccessibilityLabel("Shortcut for \(fieldTitle)")
        setAccessibilityValue(displayText)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        outline.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        outline.lineWidth = isRecording ? 2 : 1
        outline.stroke()

        let hasValue = shortcut != nil || isRecording
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: hasValue ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ]
        let text = displayText as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
