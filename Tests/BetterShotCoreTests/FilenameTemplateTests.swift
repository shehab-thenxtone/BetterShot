import Foundation
import Testing
@testable import BetterShotCore

struct FilenameTemplateTests {
    // 2026-08-26 11:30:34 UTC
    private let date = Date(timeIntervalSince1970: 1_787_743_834)
    private let utc = TimeZone(identifier: "UTC")!

    @Test func defaultTemplateMatchesSystemStyle() {
        let name = FilenameTemplate.default.filename(for: date, fileExtension: "png", timeZone: utc)
        #expect(name == "Screenshot 2026-08-26 at 11.30.34.png")
    }

    @Test func recordingsAreNamedLikeScreenRecordings() {
        let name = FilenameTemplate.recording.filename(for: date, fileExtension: "mp4", timeZone: utc)
        #expect(name == "Screen Recording 2026-08-26 at 11.30.34.mp4")
    }

    @Test func substitutesTokensInCustomTemplate() {
        let template = FilenameTemplate(rawValue: "shot_{date}_{time}")
        #expect(template.filename(for: date, fileExtension: "gif", timeZone: utc) == "shot_2026-08-26_11.30.34.gif")
    }

    @Test func stripsCharactersIllegalInFilenames() {
        let template = FilenameTemplate(rawValue: "a/b:c {date}")
        let name = template.filename(for: date, fileExtension: "png", timeZone: utc)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }

    @Test func fallsBackToDefaultWhenTemplateIsBlank() {
        let name = FilenameTemplate(rawValue: "   ").filename(for: date, fileExtension: "png", timeZone: utc)
        #expect(name == "Screenshot 2026-08-26 at 11.30.34.png")
    }
}
