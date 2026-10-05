/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Selector conditions")
struct SelectorConditionsTest {

    private static let shown = ThomasSelectorEnvironment(darkMode: false, windowSize: .medium, orientation: .portrait)

    /// A media URL selector naming `conditions`; its fields are the shared ones every selector has.
    private static func selector(_ conditions: String) throws -> ThomasMediaUrlSelector {
        let separator = conditions.isEmpty ? "" : ", "
        return try JSONDecoder().decode(
            ThomasMediaUrlSelector.self,
            from: Data(#"{\#(conditions)\#(separator)"url": "selected.png"}"#.utf8)
        )
    }

    @Test("a selector naming nothing matches anything")
    func emptyMatches() throws {
        #expect(try Self.selector("").matches(Self.shown))
    }

    @Test(
        "each field matches only its own value",
        arguments: [
            (#""platform": "ios""#, true),
            (#""platform": "android""#, false),
            (#""dark_mode": false"#, true),
            (#""dark_mode": true"#, false),
            (#""window_size": "medium""#, true),
            (#""window_size": "large""#, false),
            (#""orientation": "portrait""#, true),
            (#""orientation": "landscape""#, false),
        ]
    )
    func eachField(conditions: String, expected: Bool) throws {
        #expect(try Self.selector(conditions).matches(Self.shown) == expected)
    }

    @Test("every named field has to hold")
    func allFieldsHold() throws {
        #expect(try Self.selector(#""window_size": "medium", "orientation": "portrait""#).matches(Self.shown))
        #expect(try !Self.selector(#""window_size": "medium", "orientation": "landscape""#).matches(Self.shown))
    }

    @Test("the orientation can be left out, for a placement that locks one")
    func ignoringOrientation() throws {
        let selector = try Self.selector(#""window_size": "medium", "orientation": "landscape""#)
        #expect(selector.matches(Self.shown, ignoringOrientation: true))
    }

    @Test("an unknown window size or orientation matches no selector naming one")
    func unknownValues() throws {
        let unknown = ThomasSelectorEnvironment(darkMode: false)
        #expect(try !Self.selector(#""orientation": "portrait""#).matches(unknown))
        #expect(try !Self.selector(#""window_size": "medium""#).matches(unknown))
        #expect(try Self.selector(#""dark_mode": false"#).matches(unknown))
    }

    @MainActor
    @Test("a scene shown with no window size picks no orientation's URL until it knows the window")
    func unmeasuredOrientationPicksNoURL() throws {
        let selectors = try JSONDecoder().decode([ThomasMediaUrlSelector].self, from: Data(#"""
        [{"orientation": "landscape", "url": "landscape.png"}, {"orientation": "portrait", "url": "portrait.png"}]
        """#.utf8))
        let tracker = ThomasOrientationTracker()
        let environment = { ThomasSelectorEnvironment(darkMode: false, windowSize: .small, orientation: tracker.orientation) }
        #expect(selectors.resolve(environment()) == nil)

        tracker.update(CGSize(width: 390, height: 844))
        #expect(selectors.resolve(environment()) == "portrait.png")
    }

    private static func color(_ selectors: String) throws -> ThomasColor {
        try JSONDecoder().decode(ThomasColor.self, from: Data(#"""
        {"default": {"type": "hex", "hex": "#000000"}, "selectors": [\#(selectors)]}
        """#.utf8))
    }

    @Test("a color follows the window size and orientation, else its default")
    func colorSelectors() throws {
        let color = try Self.color(#"""
        {"window_size": "large", "color": {"type": "hex", "hex": "#111111"}},
        {"orientation": "landscape", "color": {"type": "hex", "hex": "#222222"}}
        """#)
        let large = ThomasSelectorEnvironment(darkMode: false, windowSize: .large, orientation: .portrait)
        let landscape = ThomasSelectorEnvironment(darkMode: false, windowSize: .medium, orientation: .landscape)
        #expect(color.selectors?.firstMatch(large)?.color.hex == "#111111")
        #expect(color.selectors?.firstMatch(landscape)?.color.hex == "#222222")
        #expect(color.selectors?.firstMatch(Self.shown) == nil)
    }

    @Test("a media URL follows the window size and the platform together")
    func mediaSelectors() throws {
        let selectors = try JSONDecoder().decode([ThomasMediaUrlSelector].self, from: Data(#"""
        [{"platform": "android", "window_size": "large", "url": "android-large.png"},
         {"platform": "ios", "window_size": "large", "url": "ios-large.png"}]
        """#.utf8))
        let large = ThomasSelectorEnvironment(darkMode: false, windowSize: .large, orientation: .portrait)
        #expect(selectors.resolve(large) == "ios-large.png")
        #expect(selectors.resolve(Self.shown) == nil)
    }

    /// An embedded presentation whose default placement is 100% wide and each selector's is `n0%`, n from 1.
    private static func placementChosen(_ selectors: [String], _ environment: ThomasSelectorEnvironment) throws -> Int {
        let entries = selectors.enumerated().map { index, conditions in
            #"{\#(conditions), "placement": {"size": {"width": "\#(index + 1)0%", "height": "auto"}}}"#
        }
        let presentation = try JSONDecoder().decode(ThomasPresentationInfo.Embedded.self, from: Data(#"""
        {"type": "embedded", "embedded_id": "test",
         "default_placement": {"size": {"width": "100%", "height": "auto"}},
         "placement_selectors": [\#(entries.joined(separator: ","))]}
        """#.utf8))
        let placement = ThomasPresentationInfo.placement(
            selectors: presentation.placementSelectors,
            defaultPlacement: presentation.defaultPlacement,
            in: environment
        )
        guard case .percent(let percent) = placement.size.width else { return -1 }
        return percent == 100 ? 0 : Int(percent / 10)
    }

    @Test("a placement selector matches the platform and dark mode")
    func placementPlatformAndDarkMode() throws {
        #expect(try Self.placementChosen([#""platform": "android""#, #""platform": "ios""#], Self.shown) == 2)
        let dark = ThomasSelectorEnvironment(darkMode: true, windowSize: .medium, orientation: .portrait)
        #expect(try Self.placementChosen([#""dark_mode": true"#], dark) == 1)
        #expect(try Self.placementChosen([#""dark_mode": true"#], Self.shown) == 0)
    }

    @Test("the first matching placement selector wins")
    func placementFirstMatch() throws {
        let selectors = [#""window_size": "medium""#, #""orientation": "portrait""#]
        #expect(try Self.placementChosen(selectors, Self.shown) == 1)
    }
}
