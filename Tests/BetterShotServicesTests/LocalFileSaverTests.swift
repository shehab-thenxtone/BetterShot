import BetterShotCore
import Foundation
import Testing
@testable import BetterShotServices

struct LocalFileSaverTests {
    private final class FixedFolderStore: SaveFolderStoring, @unchecked Sendable {
        var folder: URL
        init(_ folder: URL) { self.folder = folder }
        func setFolder(_ url: URL) { folder = url }
    }

    // 2026-08-26 11:30:34 UTC
    private let date = Date(timeIntervalSince1970: 1_787_743_834)
    private let utc = TimeZone(identifier: "UTC")!

    private func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSource(in folder: URL, contents: String = "video bytes") throws -> URL {
        let url = folder.appendingPathComponent("source.tmp")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test func copiesTheFileIntoTheSaveFolderNamedLikeAScreenRecording() throws {
        let work = try makeFolder()
        let destination = try makeFolder()
        defer { try? FileManager.default.removeItem(at: work); try? FileManager.default.removeItem(at: destination) }
        let source = try makeSource(in: work)

        let saver = LocalFileSaver(folderStore: FixedFolderStore(destination), timeZone: utc)
        let saved = try saver.copy(source, fileExtension: "mp4", at: date)

        #expect(saved.lastPathComponent == "Screen Recording 2026-08-26 at 11.30.34.mp4")
        #expect(try String(contentsOf: saved, encoding: .utf8) == "video bytes")
        #expect(FileManager.default.fileExists(atPath: source.path)) // a copy, not a move
    }

    @Test func neverOverwritesAnExistingFile() throws {
        let work = try makeFolder()
        let destination = try makeFolder()
        defer { try? FileManager.default.removeItem(at: work); try? FileManager.default.removeItem(at: destination) }
        let source = try makeSource(in: work)
        let saver = LocalFileSaver(folderStore: FixedFolderStore(destination), timeZone: utc)

        let first = try saver.copy(source, fileExtension: "gif", at: date)
        let second = try saver.copy(source, fileExtension: "gif", at: date)

        #expect(first.lastPathComponent == "Screen Recording 2026-08-26 at 11.30.34.gif")
        #expect(second.lastPathComponent == "Screen Recording 2026-08-26 at 11.30.34 2.gif")
    }

    @Test func createsTheFolderIfItIsMissing() throws {
        let work = try makeFolder()
        let parent = try makeFolder()
        defer { try? FileManager.default.removeItem(at: work); try? FileManager.default.removeItem(at: parent) }
        let source = try makeSource(in: work)
        let missing = parent.appendingPathComponent("a/b", isDirectory: true)

        let saved = try LocalFileSaver(folderStore: FixedFolderStore(missing), timeZone: utc).copy(source, fileExtension: "mp4", at: date)

        #expect(FileManager.default.fileExists(atPath: saved.path))
    }

    @Test func aMissingSourceIsAnErrorNotACrash() throws {
        let destination = try makeFolder()
        defer { try? FileManager.default.removeItem(at: destination) }
        let saver = LocalFileSaver(folderStore: FixedFolderStore(destination), timeZone: utc)

        #expect(throws: SaveError.self) {
            try saver.copy(destination.appendingPathComponent("missing.mp4"), fileExtension: "mp4", at: date)
        }
    }
}
