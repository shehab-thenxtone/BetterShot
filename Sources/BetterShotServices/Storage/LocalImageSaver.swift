import BetterShotCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Silent "Save": writes a PNG into the remembered folder using the filename template, never overwriting.
public struct LocalImageSaver: Sendable {
    private let folderStore: any SaveFolderStoring
    private let template: FilenameTemplate
    private let timeZone: TimeZone

    public init(
        folderStore: any SaveFolderStoring,
        template: FilenameTemplate = .default,
        timeZone: TimeZone = .current
    ) {
        self.folderStore = folderStore
        self.template = template
        self.timeZone = timeZone
    }

    @discardableResult
    public func savePNG(_ image: CGImage, at date: Date = Date()) throws(SaveError) -> URL {
        let data = try Self.pngData(for: image)
        let folder = folderStore.folder
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = UniqueFilename.resolve(
                template.filename(for: date, fileExtension: "png", timeZone: timeZone),
                isTaken: { fileManager.fileExists(atPath: folder.appendingPathComponent($0).path) }
            )
            let url = folder.appendingPathComponent(name)
            try data.write(to: url, options: .withoutOverwriting)
            return url
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }

    private static func pngData(for image: CGImage) throws(SaveError) -> Data {
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { throw .encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw .encodingFailed }
        return output as Data
    }
}
