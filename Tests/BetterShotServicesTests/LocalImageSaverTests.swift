import BetterShotCore
import CoreGraphics
import Foundation
import Testing
@testable import BetterShotServices

struct LocalImageSaverTests {
    private final class FixedFolderStore: SaveFolderStoring, @unchecked Sendable {
        var folder: URL
        init(_ folder: URL) { self.folder = folder }
        func setFolder(_ url: URL) { folder = url }
    }

    // 2026-08-26 11:30:34 UTC
    private let date = Date(timeIntervalSince1970: 1_787_743_834)
    private let utc = TimeZone(identifier: "UTC")!

    private func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BetterShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeImage() -> CGImage {
        let context = CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context.makeImage()!
    }

    private func makeSaver(folder: URL) -> LocalImageSaver {
        LocalImageSaver(folderStore: FixedFolderStore(folder), timeZone: utc)
    }

    @Test func writesPNGNamedFromTemplate() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let url = try makeSaver(folder: folder).savePNG(makeImage(), at: date)

        #expect(url.lastPathComponent == "Screenshot 2026-08-26 at 11.30.34.png")
        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47]) // PNG signature
    }

    @Test func doesNotOverwriteExistingFile() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let saver = makeSaver(folder: folder)

        let first = try saver.savePNG(makeImage(), at: date)
        let second = try saver.savePNG(makeImage(), at: date)

        #expect(first.lastPathComponent == "Screenshot 2026-08-26 at 11.30.34.png")
        #expect(second.lastPathComponent == "Screenshot 2026-08-26 at 11.30.34 2.png")
    }

    @Test func createsMissingFolder() throws {
        let parent = try makeFolder()
        defer { try? FileManager.default.removeItem(at: parent) }
        let missing = parent.appendingPathComponent("Nested/Screenshots", isDirectory: true)

        let url = try makeSaver(folder: missing).savePNG(makeImage(), at: date)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
