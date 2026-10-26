import Foundation
import Testing
@testable import BetterShotAnnotations

struct AnnotationToolTests {
    @Test func everyToolHasAUniqueSingleLetterShortcut() {
        let keys = AnnotationTool.allCases.map(\.defaultKey)
        #expect(Set(keys).count == keys.count)
        for key in keys {
            #expect(key.count == 1)
            #expect(key == key.lowercased())
        }
    }

    @Test func toolLookupByKeyFindsTheTool() {
        #expect(AnnotationTool.tool(forKey: "r") == .rectangle)
        #expect(AnnotationTool.tool(forKey: "A") == .arrow) // case-insensitive
        #expect(AnnotationTool.tool(forKey: "?") == nil)
    }

    @Test func highlightersAreSemiTransparentByDefault() {
        #expect(AnnotationTool.marker.defaultStyle.color.alpha < 1)
        #expect(AnnotationTool.textHighlighter.defaultStyle.color.alpha < 1)
        #expect(AnnotationTool.arrow.defaultStyle.color.alpha == 1)
    }

    @Test func toolStylesRememberTheLastStylePerTool() {
        let red = AnnotationStyle().updating(color: .scarlet)
        let blue = AnnotationStyle().updating(color: .azure, lineWeight: .thick)
        let styles = ToolStyles.defaults.setting(red, for: .arrow).setting(blue, for: .rectangle)

        #expect(styles.style(for: .arrow) == red)
        #expect(styles.style(for: .rectangle) == blue)
        #expect(styles.style(for: .ellipse) == AnnotationTool.ellipse.defaultStyle)
    }

    @Test func toolStylesRoundTripThroughJSON() throws {
        let original = ToolStyles.defaults.setting(AnnotationStyle().updating(color: .mint, arrowStyle: .open), for: .arrow)
        let decoded = try JSONDecoder().decode(ToolStyles.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func emptyOrUnknownJSONFallsBackToDefaults() throws {
        #expect(try JSONDecoder().decode(ToolStyles.self, from: Data("{}".utf8)) == .defaults)

        let json = #"{"styles": {"hologram": {"color": {"red": 1, "green": 0, "blue": 0, "alpha": 1}, "lineWeight": "thin", "arrowStyle": "solid"}}}"#
        #expect(try JSONDecoder().decode(ToolStyles.self, from: Data(json.utf8)) == .defaults)
    }

    @Test func colorComponentsAreClamped() {
        let color = AnnotationColor(red: 2, green: -1, blue: 0.5, alpha: 7)
        #expect(color.red == 1 && color.green == 0 && color.blue == 0.5 && color.alpha == 1)
    }
}
