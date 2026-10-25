import Foundation
import Testing
@testable import BetterShotServices

struct UserDefaultsSaveFolderStoreTests {
    private let defaultFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("BetterShotTests-default-\(UUID().uuidString)", isDirectory: true)

    private func makeStore() -> UserDefaultsSaveFolderStore {
        let suite = "BetterShotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return UserDefaultsSaveFolderStore(defaults: defaults, defaultFolder: defaultFolder)
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BetterShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func usesDefaultFolderOnFirstUse() {
        #expect(makeStore().folder == defaultFolder)
    }

    @Test func returnsFolderThatWasSet() throws {
        let store = makeStore()
        let chosen = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: chosen) }
        store.setFolder(chosen)
        #expect(store.folder.standardizedFileURL == chosen.standardizedFileURL)
    }

    @Test func fallsBackToDefaultWhenChosenFolderWasDeleted() throws {
        let store = makeStore()
        let chosen = try makeDirectory()
        store.setFolder(chosen)
        try FileManager.default.removeItem(at: chosen)
        #expect(store.folder == defaultFolder)
    }
}
