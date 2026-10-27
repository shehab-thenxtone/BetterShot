import BetterShotCore
import Foundation
import Testing
@testable import BetterShotServices

/// A throwaway home directory laid out like a Mac with the Drive apps installed.
private struct FakeHome {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)", isDirectory: true)

    init(_ folders: [String] = []) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for folder in folders { try make(folder) }
    }

    func make(_ relative: String) throws {
        try FileManager.default.createDirectory(at: url.appendingPathComponent(relative, isDirectory: true), withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: url) }
}

struct SyncedFolderLocatorTests {
    @Test func findsTheGoogleDriveMyDriveFolder() throws {
        let home = try FakeHome(["Library/CloudStorage/GoogleDrive-me@gmail.com/My Drive"])
        defer { home.remove() }

        let folder = SyncedFolderLocator(homeDirectory: home.url).detect(for: .googleDrive)

        #expect(folder?.path.hasSuffix("GoogleDrive-me@gmail.com/My Drive") == true)
    }

    @Test func aGoogleDriveMountWithoutMyDriveIsNotUsableYet() throws {
        let home = try FakeHome(["Library/CloudStorage/GoogleDrive-me@gmail.com"])
        defer { home.remove() }

        #expect(SyncedFolderLocator(homeDirectory: home.url).detect(for: .googleDrive) == nil)
    }

    @Test func prefersThePersonalOneDrive() throws {
        let home = try FakeHome(["Library/CloudStorage/OneDrive-Acme", "Library/CloudStorage/OneDrive-Personal"])
        defer { home.remove() }

        let folder = SyncedFolderLocator(homeDirectory: home.url).detect(for: .oneDrive)

        #expect(folder?.lastPathComponent == "OneDrive-Personal")
    }

    @Test func fallsBackToTheOlderHomeFolders() throws {
        let home = try FakeHome(["OneDrive - Contoso", "Google Drive/My Drive"])
        defer { home.remove() }
        let locator = SyncedFolderLocator(homeDirectory: home.url)

        #expect(locator.detect(for: .oneDrive)?.lastPathComponent == "OneDrive - Contoso")
        #expect(locator.detect(for: .googleDrive)?.lastPathComponent == "My Drive")
    }

    @Test func findsNothingWhenTheAppsAreNotSetUp() throws {
        let home = try FakeHome(["Documents"])
        defer { home.remove() }
        let locator = SyncedFolderLocator(homeDirectory: home.url)

        #expect(locator.detect(for: .googleDrive) == nil)
        #expect(locator.detect(for: .oneDrive) == nil)
    }
}

struct SyncedFoldersTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "com.bettershot.tests.\(UUID().uuidString)")!
    }

    @Test func aFolderTheUserPickedWinsOverTheDetectedOne() throws {
        let home = try FakeHome(["Library/CloudStorage/OneDrive-Personal", "Elsewhere"])
        defer { home.remove() }
        let folders = SyncedFolders(defaults: defaults(), locator: SyncedFolderLocator(homeDirectory: home.url))
        let picked = home.url.appendingPathComponent("Elsewhere", isDirectory: true)

        folders.choose(picked, for: .oneDrive)

        #expect(folders.folder(for: .oneDrive)?.path == picked.path)
        #expect(folders.chosenFolder(for: .googleDrive) == nil) // per provider
    }

    @Test func goingBackToTheDetectedFolderForgetsTheChoice() throws {
        let home = try FakeHome(["Library/CloudStorage/OneDrive-Personal", "Elsewhere"])
        defer { home.remove() }
        let folders = SyncedFolders(defaults: defaults(), locator: SyncedFolderLocator(homeDirectory: home.url))
        folders.choose(home.url.appendingPathComponent("Elsewhere", isDirectory: true), for: .oneDrive)

        folders.choose(nil, for: .oneDrive)

        #expect(folders.folder(for: .oneDrive)?.lastPathComponent == "OneDrive-Personal")
    }

    @Test func aPickedFolderThatNoLongerExistsFallsBackToTheDetectedOne() throws {
        let home = try FakeHome(["Library/CloudStorage/OneDrive-Personal", "Gone"])
        defer { home.remove() }
        let folders = SyncedFolders(defaults: defaults(), locator: SyncedFolderLocator(homeDirectory: home.url))
        let gone = home.url.appendingPathComponent("Gone", isDirectory: true)
        folders.choose(gone, for: .oneDrive)
        try FileManager.default.removeItem(at: gone)

        #expect(folders.chosenFolder(for: .oneDrive) == nil)
        #expect(folders.folder(for: .oneDrive)?.lastPathComponent == "OneDrive-Personal")
    }
}

struct SyncedFolderUploaderTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])

    @Test func copiesIntoABetterShotFolderAndNeverOverwrites() async throws {
        let home = try FakeHome(["Drive"])
        defer { home.remove() }
        let uploader = SyncedFolderUploader(root: home.url.appendingPathComponent("Drive", isDirectory: true))

        let first = try await uploader.upload(png, filename: "Shot 1.png", mimeType: "image/png")
        let second = try await uploader.upload(png, filename: "Shot 1.png", mimeType: "image/png")

        #expect(first.location.deletingLastPathComponent().lastPathComponent == "BetterShot")
        #expect(first.location != second.location)
        #expect(try Data(contentsOf: first.location) == png)
        #expect(!first.isShareableLink) // the desktop app syncs it, but no link is created
    }

    @Test func aMissingFolderIsReportedRatherThanCreated() async throws {
        let uploader = SyncedFolderUploader(root: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))

        await #expect(throws: SyncedFolderError.folderMissing) { try await uploader.upload(png, filename: "a.png", mimeType: "image/png") }
    }
}
