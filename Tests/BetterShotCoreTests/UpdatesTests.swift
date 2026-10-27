import Foundation
import Testing
@testable import BetterShotCore

struct AppVersionTests {
    @Test func parsesCommonForms() {
        #expect(AppVersion("1.2.3")?.components == [1, 2, 3])
        #expect(AppVersion("v0.1.0")?.components == [0, 1, 0])
        #expect(AppVersion(" 2.0 ")?.components == [2, 0])
        #expect(AppVersion("1.2.3-beta.1")?.components == [1, 2, 3])
        #expect(AppVersion("1.2.3+45")?.components == [1, 2, 3])
    }

    @Test func rejectsNonVersions() {
        for text in ["", "latest", "1..2", "1.x", "-1.0", "v"] {
            #expect(AppVersion(text) == nil, "\(text) should not parse")
        }
    }

    @Test func comparesNumericallyNotAlphabetically() throws {
        #expect(try #require(AppVersion("1.10")) > #require(AppVersion("1.9")))
        #expect(try #require(AppVersion("2.0.0")) > #require(AppVersion("1.99.99")))
        #expect(try #require(AppVersion("0.1.0")) < #require(AppVersion("0.1.1")))
    }

    @Test func missingTrailingPartsCountAsZero() throws {
        #expect(try #require(AppVersion("1.2")) == #require(AppVersion("1.2.0")))
        #expect(try #require(AppVersion("1.2.1")) > #require(AppVersion("1.2")))
    }

    @Test func printsWithoutThePrefix() {
        #expect(AppVersion("v1.4.0")?.description == "1.4.0")
    }
}

struct UpdateFeedTests {
    private func json(_ tag: String, url: String = "https://example.com/releases/1", draft: Bool = false, prerelease: Bool = false) -> Data {
        Data(#"{"tag_name":"\#(tag)","html_url":"\#(url)","draft":\#(draft),"prerelease":\#(prerelease)}"#.utf8)
    }

    @Test func readsALatestRelease() {
        let update = UpdateFeed.release(from: json("v1.2.0"))

        #expect(update == AvailableUpdate(version: AppVersion("1.2.0")!, pageURL: URL(string: "https://example.com/releases/1")!))
    }

    @Test func ignoresDraftsAndPrereleases() {
        #expect(UpdateFeed.release(from: json("v2.0.0", draft: true)) == nil)
        #expect(UpdateFeed.release(from: json("v2.0.0", prerelease: true)) == nil)
    }

    @Test func ignoresUnreadableOrUnsafeFeeds() {
        #expect(UpdateFeed.release(from: Data("nope".utf8)) == nil)
        #expect(UpdateFeed.release(from: json("nightly")) == nil)
        #expect(UpdateFeed.release(from: json("v1.0.0", url: "http://example.com/plain")) == nil)
        #expect(UpdateFeed.release(from: json("v1.0.0", url: "file:///etc/passwd")) == nil)
    }
}
