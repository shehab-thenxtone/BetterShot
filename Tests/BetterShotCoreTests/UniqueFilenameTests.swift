import Testing
@testable import BetterShotCore

struct UniqueFilenameTests {
    @Test func keepsNameWhenFree() {
        #expect(UniqueFilename.resolve("Shot.png", isTaken: { _ in false }) == "Shot.png")
    }

    @Test func appendsTwoWhenTaken() {
        let taken: Set = ["Shot.png"]
        #expect(UniqueFilename.resolve("Shot.png", isTaken: taken.contains) == "Shot 2.png")
    }

    @Test func skipsToNextFreeNumber() {
        let taken: Set = ["Shot.png", "Shot 2.png", "Shot 3.png"]
        #expect(UniqueFilename.resolve("Shot.png", isTaken: taken.contains) == "Shot 4.png")
    }

    @Test func onlyTreatsLastDotAsExtension() {
        let name = "Screenshot 2026-08-26 at 11.30.34.png"
        let taken: Set = [name]
        #expect(UniqueFilename.resolve(name, isTaken: taken.contains) == "Screenshot 2026-08-26 at 11.30.34 2.png")
    }

    @Test func handlesNamesWithoutExtension() {
        let taken: Set = ["Shot"]
        #expect(UniqueFilename.resolve("Shot", isTaken: taken.contains) == "Shot 2")
    }
}
