import CoreGraphics
import Foundation
import ImageIO

/// The single "recently closed" capture (requirements §4.4): the last image the user closed or discarded without
/// keeping, saved to Application Support so "Restore Recently Closed File" works even after a relaunch.
/// There is deliberately no history: each save replaces the previous one.
public final class RecentlyClosedStore: @unchecked Sendable { // all file access goes through `queue`
    public static let fileName = "RecentlyClosed.png"

    public static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("BetterShot", isDirectory: true)
    }

    private let directory: URL
    private let queue = DispatchQueue(label: "com.bettershot.recently-closed", qos: .utility)

    public init(directory: URL = RecentlyClosedStore.defaultDirectory) {
        self.directory = directory
    }

    private var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    /// Writes in the background so closing a window never waits on PNG encoding. Reads queue behind it.
    public func save(_ image: CGImage) {
        queue.async { [directory, fileURL] in
            guard let data = try? ImageExporter.data(for: image, format: .png) else { return }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public var hasItem: Bool {
        queue.sync { FileManager.default.fileExists(atPath: fileURL.path) }
    }

    /// Returns the stored image and empties the slot, like reopening a closed tab. Nil if there is none or the
    /// file is unreadable (which also clears it).
    public func take() -> CGImage? {
        queue.sync {
            defer { try? FileManager.default.removeItem(at: fileURL) }
            guard
                let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            return image
        }
    }
}
