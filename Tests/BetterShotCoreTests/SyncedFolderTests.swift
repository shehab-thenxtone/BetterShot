import Testing
@testable import BetterShotCore

struct SyncedFolderTests {
    @Test func recognisesTheCloudStorageMounts() {
        #expect(SyncedFolder.isMountName("GoogleDrive-someone@gmail.com", for: .googleDrive))
        #expect(SyncedFolder.isMountName("OneDrive-Personal", for: .oneDrive))
        #expect(SyncedFolder.isMountName("OneDrive-Contoso", for: .oneDrive))
        #expect(SyncedFolder.isMountName("OneDrive", for: .oneDrive))
    }

    @Test func doesNotMixUpProvidersOrLookalikes() {
        #expect(!SyncedFolder.isMountName("OneDrive-Personal", for: .googleDrive))
        #expect(!SyncedFolder.isMountName("GoogleDrive-a@b.c", for: .oneDrive))
        #expect(!SyncedFolder.isMountName("OneDriveBackup", for: .oneDrive))
        #expect(!SyncedFolder.isMountName("Dropbox", for: .googleDrive))
    }

    @Test func recognisesTheOlderHomeFolderLocations() {
        #expect(SyncedFolder.isLegacyName("Google Drive", for: .googleDrive))
        #expect(SyncedFolder.isLegacyName("OneDrive", for: .oneDrive))
        #expect(SyncedFolder.isLegacyName("OneDrive - Contoso", for: .oneDrive))
        #expect(!SyncedFolder.isLegacyName("Documents", for: .oneDrive))
    }

    @Test func googleDriveFilesLiveInMyDriveAndOneDriveInTheRoot() {
        #expect(SyncedFolder.uploadSubfolder(for: .googleDrive) == "My Drive")
        #expect(SyncedFolder.uploadSubfolder(for: .oneDrive) == nil)
    }

    @Test func personalAccountsComeFirstThenAlphabetical() {
        let ordered = SyncedFolder.ordered(["OneDrive-Zeta", "OneDrive-Acme", "OneDrive-Personal"])

        #expect(ordered == ["OneDrive-Personal", "OneDrive-Acme", "OneDrive-Zeta"])
    }

    @Test func knowsWhichAppDoesTheSyncing() {
        #expect(SyncedFolder.syncApp(for: .googleDrive).bundleIdentifier == "com.google.drivefs")
        #expect(SyncedFolder.syncApp(for: .oneDrive).name == "OneDrive")
    }
}
