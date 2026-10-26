import CoreGraphics
import Foundation
import Testing
@testable import BetterShotServices

struct RecentlyClosedStoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BetterShotTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test func anEmptyStoreHasNothingToRestore() {
        let store = RecentlyClosedStore(directory: makeDirectory())
        #expect(!store.hasItem)
        #expect(store.take() == nil)
    }

    @Test func takingReturnsTheSavedImageAndEmptiesTheSlot() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecentlyClosedStore(directory: directory)

        store.save(makeImage(width: 30, height: 20))
        #expect(store.hasItem)

        let restored = try #require(store.take())
        #expect(restored.width == 30 && restored.height == 20)
        #expect(!store.hasItem)
        #expect(store.take() == nil)
    }

    @Test func savingAgainReplacesThePreviousImage() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecentlyClosedStore(directory: directory)

        store.save(makeImage(width: 10, height: 10))
        store.save(makeImage(width: 40, height: 25))

        let restored = try #require(store.take())
        #expect(restored.width == 40 && restored.height == 25) // only the last closed capture is kept
    }

    @Test func aCorruptFileYieldsNothingAndIsCleared() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not an image".utf8).write(to: directory.appendingPathComponent(RecentlyClosedStore.fileName))

        let store = RecentlyClosedStore(directory: directory)
        #expect(store.take() == nil)
        #expect(!store.hasItem)
    }

    @Test func theDirectoryIsCreatedOnDemand() {
        let directory = makeDirectory().appendingPathComponent("nested/BetterShot", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent().deletingLastPathComponent()) }
        let store = RecentlyClosedStore(directory: directory)

        store.save(makeImage(width: 5, height: 5))

        #expect(store.hasItem)
    }
}
