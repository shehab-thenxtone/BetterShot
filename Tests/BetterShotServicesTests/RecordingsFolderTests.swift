import Foundation
import Testing
@testable import BetterShotServices

struct RecordingsFolderTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeFile(named name: String, in directory: URL, modified: Date) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func removesOnlyFilesOlderThanTheAge() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date()
        let old = try makeFile(named: "old.mp4", in: directory, modified: now.addingTimeInterval(-10 * 86_400))
        let recent = try makeFile(named: "recent.mp4", in: directory, modified: now.addingTimeInterval(-86_400))

        RecordingsFolder.removeFiles(in: directory, olderThan: 7 * 86_400, now: now)

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
    }

    @Test func aMissingFolderIsNotAnError() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString)")
        RecordingsFolder.removeFiles(in: missing, olderThan: 86_400) // must simply return
    }

    @Test func newRecordingsGetUniqueMP4NamesInsideTheFolder() {
        let directory = FileManager.default.temporaryDirectory
        let first = RecordingsFolder.url(forNewRecordingIn: directory)
        let second = RecordingsFolder.url(forNewRecordingIn: directory)
        #expect(first != second)
        #expect(first.pathExtension == "mp4")
        #expect(first.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
    }
}
