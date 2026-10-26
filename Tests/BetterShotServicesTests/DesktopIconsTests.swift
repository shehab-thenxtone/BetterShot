import Testing
@testable import BetterShotServices

struct DesktopIconsTests {
    /// Stands in for Finder's `CreateDesktop` preference and for restarting Finder.
    private final class FakeFinder: @unchecked Sendable {
        var createDesktop: Bool?
        var writes: [Bool] = []
        var restarts = 0

        init(createDesktop: Bool? = nil) { self.createDesktop = createDesktop }

        var icons: DesktopIcons {
            DesktopIcons(
                readCreateDesktop: { self.createDesktop },
                writeCreateDesktop: { self.createDesktop = $0; self.writes.append($0) },
                restartFinder: { self.restarts += 1 }
            )
        }
    }

    @Test func iconsAreShownWhenFinderHasNoSetting() {
        #expect(!FakeFinder(createDesktop: nil).icons.areHidden)
    }

    @Test func iconsAreShownWhenCreateDesktopIsTrue() {
        #expect(!FakeFinder(createDesktop: true).icons.areHidden)
    }

    @Test func iconsAreHiddenWhenCreateDesktopIsFalse() {
        #expect(FakeFinder(createDesktop: false).icons.areHidden)
    }

    @Test func hidingTurnsOffCreateDesktopAndRestartsFinderOnce() {
        let finder = FakeFinder(createDesktop: nil)
        finder.icons.setHidden(true)
        #expect(finder.writes == [false])
        #expect(finder.restarts == 1)
    }

    @Test func showingTurnsCreateDesktopBackOnAndRestartsFinderOnce() {
        let finder = FakeFinder(createDesktop: false)
        finder.icons.setHidden(false)
        #expect(finder.writes == [true])
        #expect(finder.restarts == 1)
    }

    @Test func settingTheCurrentStateDoesNothing() {
        let hidden = FakeFinder(createDesktop: false)
        hidden.icons.setHidden(true)
        let shown = FakeFinder(createDesktop: true)
        shown.icons.setHidden(false)

        #expect(hidden.writes.isEmpty && hidden.restarts == 0)
        #expect(shown.writes.isEmpty && shown.restarts == 0) // no needless Finder restart
    }
}
