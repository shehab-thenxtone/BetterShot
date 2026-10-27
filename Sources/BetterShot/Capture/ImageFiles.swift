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

    /// What "Open…" can be given: a picture for the editor, or a screen recording.
    enum OpenedMedia {
        case image(LoadedImage)
        case video(URL)
    }

    /// Open panel for an image or a recording. Nil if cancelled; tells the user if an image can't be read.
    @MainActor
    static func chooseMedia(message: String) -> OpenedMedia? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        panel.message = message

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .movie) {
            return .video(url)
        }
        guard let loaded = load(url) else {
            CaptureAlerts.presentInfo(title: "Couldn't open file", message: "\(url.lastPathComponent) isn't a readable image or recording.", style: .warning)
            return nil
        }
        return .image(loaded)
    }

    /// Same, when only the pixels matter.
    @MainActor
    static func choose(message: String) -> CGImage? {
        chooseWithScale(message: message)?.image
    }
}
