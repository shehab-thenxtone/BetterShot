import AppKit
import BetterShotCore
import ImageIO
import UniformTypeIdentifiers

/// An image read from disk, with the points-per-pixel scale its DPI metadata implies (nil if it records none).
struct LoadedImage {
    let image: CGImage
    let pointScale: CGFloat?
}

/// Reading images from disk and asking the user for one.
enum ImageFiles {
    static func load(_ url: URL) -> LoadedImage? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpi = (properties?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue
        return LoadedImage(image: image, pointScale: ImageScale.pointScale(forDPI: dpi))
    }

    /// Shows an Open panel for an image file. Returns nil if cancelled; tells the user if the file can't be read.
    @MainActor
    static func chooseWithScale(message: String) -> LoadedImage? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = message

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        guard let loaded = load(url) else {
            CaptureAlerts.presentInfo(title: "Couldn't open image", message: "\(url.lastPathComponent) isn't a readable image.", style: .warning)
            return nil
        }
        return loaded
    }

    /// Same, when only the pixels matter.
    @MainActor
    static func choose(message: String) -> CGImage? {
        chooseWithScale(message: message)?.image
    }
}
