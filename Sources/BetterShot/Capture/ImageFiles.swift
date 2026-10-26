import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Reading images from disk and asking the user for one.
enum ImageFiles {
    static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Shows an Open panel for an image file. Returns nil if cancelled; tells the user if the file can't be read.
    @MainActor
    static func choose(message: String) -> CGImage? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = message

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        guard let image = load(url) else {
            CaptureAlerts.presentInfo(title: "Couldn't open image", message: "\(url.lastPathComponent) isn't a readable image.", style: .warning)
            return nil
        }
        return image
    }
}
