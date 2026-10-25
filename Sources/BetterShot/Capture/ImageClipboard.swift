import AppKit

enum ImageClipboard {
    @MainActor
    static func copy(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)])
    }
}
