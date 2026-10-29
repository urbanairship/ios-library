/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Label markdown colors")
@MainActor
struct LabelMarkdownColorTest {

    private typealias SceneLabel = AirshipSceneRenderer.Label

    private static let environment = ThomasSelectorEnvironment(darkMode: false)
    private static let red = Color(red: 1, green: 0, blue: 0)

    private static func parse(_ markdown: String) throws -> AttributedString {
        try AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }

    /// Each span found in `markdown` as (inner text, color name, outer text).
    private static func spans(_ markdown: String) throws -> [(inner: String, name: String, outer: String)] {
        let chars = try parse(markdown).characters
        return SceneLabel.findColorSpans(in: chars).map {
            (String(chars[$0.range.inner]), $0.colorName, String(chars[$0.range.outer]))
        }
    }

    private static func anchor(_ json: String) throws -> ThomasMarkDownOptions.Appearance.Anchor {
        try JSONDecoder().decode(ThomasMarkDownOptions.Appearance.Anchor.self, from: Data(json.utf8))
    }

    @Test("finds each span's text and color name")
    func findsSpans() throws {
        let found = try Self.spans("[Sale]{color:brand} ends [today]{color:urgent}, so don't miss it")
        #expect(found.map(\.inner) == ["Sale", "today"])
        #expect(found.map(\.name) == ["brand", "urgent"])
        #expect(found.map(\.outer) == ["[Sale]{color:brand}", "[today]{color:urgent}"])
    }

    @Test("markdown inside the brackets is already applied")
    func markdownInside() throws {
        let found = try Self.spans("[**Sale** now]{color:brand}")
        #expect(found.map(\.inner) == ["Sale now"])
    }

    @Test("a link inside a span stays part of its text")
    func linkInside() throws {
        let found = try Self.spans("[read the [docs](https://www.airship.com) today]{color:urgent}")
        #expect(found.map(\.inner) == ["read the docs today"])
    }

    @Test("nested spans are returned innermost first")
    func nested() throws {
        let found = try Self.spans("[one [two [three]{color:c} two]{color:b} one]{color:a}")
        #expect(found.map(\.name) == ["c", "b", "a"])
        #expect(found.first?.inner == "three")
    }

    @Test("an unmatched bracket doesn't stop later spans")
    func unmatchedBracket() throws {
        #expect(try Self.spans("a ] b [ c [ok]{color:a}").map(\.inner) == ["ok"])
    }

    @Test(
        "text that isn't a span is left alone",
        arguments: [
            "[space] {color:brand}",
            "[x]{color:}",
            "[y]{color:two words}",
            "[]{color:brand}",
            "[open]{color:brand",
            "[parens](color:brand)",
            "[x]{colour:brand}",
            "plain {color:brand}",
        ]
    )
    func notSpans(markdown: String) throws {
        #expect(try Self.spans(markdown).isEmpty)
    }

    @Test("span color skips links")
    func spanColorSkipsLinks() throws {
        var attributed = try Self.parse("a [docs](https://www.airship.com) b")
        SceneLabel.applySpanColor(Self.red, to: &attributed)

        for run in attributed.runs {
            let expected: Color? = run.link == nil ? Self.red : nil
            #expect(run.attributes.swiftUI.foregroundColor == expected)
        }
    }

    @Test("anchor color and underline go on links only")
    func anchorStylesLinks() throws {
        let anchor = try Self.anchor(##"{"color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}, "styles": ["underlined"]}"##)
        let anchorColor = try #require(anchor.color).toColor(Self.environment)

        var attributed = try Self.parse("a [docs](https://www.airship.com) b")
        SceneLabel.applyAnchorAppearance(anchor, to: &attributed, selectorEnvironment: Self.environment)

        for run in attributed.runs {
            let isLink = run.link != nil
            #expect(run.attributes.swiftUI.foregroundColor == (isLink ? anchorColor : nil))
            #expect(run.attributes.swiftUI.underlineStyle == (isLink ? Text.LineStyle.single : nil))
        }
    }

    @Test("an anchor without styles doesn't underline")
    func anchorWithoutUnderline() throws {
        let anchor = try Self.anchor(##"{"color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}}"##)

        var attributed = try Self.parse("[docs](https://www.airship.com)")
        SceneLabel.applyAnchorAppearance(anchor, to: &attributed, selectorEnvironment: Self.environment)

        #expect(attributed.runs.allSatisfy { $0.attributes.swiftUI.underlineStyle == nil })
    }

    @Test("no anchor leaves links unstyled")
    func noAnchor() throws {
        let original = try Self.parse("a [docs](https://www.airship.com) b")
        var attributed = original
        SceneLabel.applyAnchorAppearance(nil, to: &attributed, selectorEnvironment: Self.environment)

        #expect(attributed == original)
    }

    @Test("a span takes its color from the scene's named colors, selectors and all")
    func spanColorFromScene() throws {
        let urgent = try JSONDecoder().decode(ThomasColor.Definition.self, from: Data(#"""
        {
          "default": { "type": "hex", "hex": "#D0021B", "alpha": 1 },
          "selectors": [{ "dark_mode": true, "color": { "type": "hex", "hex": "#FF6B6B", "alpha": 1 } }]
        }
        """#.utf8))
        let light = ThomasSelectorEnvironment(darkMode: false, colors: ["urgent": urgent])
        let dark = ThomasSelectorEnvironment(darkMode: true, colors: ["urgent": urgent])

        #expect(SceneLabel.spanColor(named: "urgent", in: light) == urgent.toColor(light))
        #expect(SceneLabel.spanColor(named: "urgent", in: dark) == urgent.toColor(dark))
        #expect(SceneLabel.spanColor(named: "urgent", in: light) != SceneLabel.spanColor(named: "urgent", in: dark))
    }

    @Test("a span naming a color the scene doesn't define keeps the label's color")
    func spanColorUnknown() {
        #expect(SceneLabel.spanColor(named: "brand", in: Self.environment) == nil)
        #expect(SceneLabel.spanColor(named: nil, in: Self.environment) == nil)
    }
}
