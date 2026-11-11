/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Label markdown")
@MainActor
struct LabelMarkdownTest {

    private typealias SceneLabel = AirshipSceneRenderer.Label

    private static let fontSize = 20.0
    private static let link = URL(string: "https://www.airship.com")!

    private static let environment: ThomasSelectorEnvironment = {
        let brand = try! JSONDecoder().decode(
            ThomasColor.Definition.self,
            from: Data(##"{"default": {"type": "hex", "hex": "#C8336C", "alpha": 1}}"##.utf8)
        )
        return ThomasSelectorEnvironment(darkMode: false, colors: ["brand": brand])
    }()

    private static var brand: Color { SceneLabel.spanColor(named: "brand", in: environment)! }

    private struct Run: Equatable, CustomStringConvertible {
        var text: String
        var bold = false
        var italic = false
        var code = false
        var link: URL? = nil
        var color: Color? = nil
        var highlighted = false
        var baselineOffset: Double? = nil

        /// The run with its text cleared, for comparing styles.
        var style: Run {
            var copy = self
            copy.text = ""
            return copy
        }

        var description: String {
            "\(text.debugDescription) bold:\(bold) italic:\(italic) code:\(code) link:\(link?.absoluteString ?? "-") "
                + "color:\(color.map { "\($0)" } ?? "-") highlighted:\(highlighted) offset:\(baselineOffset.map { "\($0)" } ?? "-")"
        }
    }

    private static func render(_ markdown: String, options: ThomasMarkDownOptions? = nil) throws -> AttributedString {
        let textAppearance = try JSONDecoder().decode(
            ThomasTextAppearance.self,
            from: Data(##"{"font_size": 20, "color": {"default": {"type": "hex", "hex": "#000000", "alpha": 1}}}"##.utf8)
        )
        return try SceneLabel.markdownAttributedString(
            markdown,
            options: options,
            textAppearance: textAppearance,
            scaledFontSize: fontSize,
            selectorEnvironment: environment
        )
    }

    /// The rendered text as runs, with adjacent runs that look the same merged.
    private static func runs(_ markdown: String) throws -> [Run] {
        let attributed = try render(markdown)
        var result: [Run] = []
        for run in attributed.runs {
            let intent = run.inlinePresentationIntent ?? []
            let next = Run(
                text: String(attributed[run.range].characters),
                bold: intent.contains(.stronglyEmphasized),
                italic: intent.contains(.emphasized),
                code: intent.contains(.code),
                link: run.link,
                color: run.attributes.swiftUI.foregroundColor,
                highlighted: run.attributes.swiftUI.backgroundColor != nil,
                baselineOffset: run.attributes.swiftUI.baselineOffset.map(Double.init)
            )
            if var last = result.last, last.style == next.style {
                last.text += next.text
                result[result.count - 1] = last
            } else {
                result.append(next)
            }
        }
        return result
    }

    @Test("an escaped highlight, superscript or subscript delimiter stays literal")
    func escapedDelimiters() throws {
        #expect(try Self.runs(#"\==not highlight=="#) == [Run(text: "==not highlight==")])
        #expect(try Self.runs(#"\^^not sup^^"#) == [Run(text: "^^not sup^^")])
        #expect(try Self.runs(#"\,{not sub},"#) == [Run(text: ",{not sub},")])
        #expect(try Self.runs(#"a\=b \^ c\,d"#) == [Run(text: "a=b ^ c,d")])
    }

    @Test("an escaped delimiter keeps the styling around it")
    func escapedDelimiterInsideFormatting() throws {
        #expect(try Self.runs(#"**a\=b**"#) == [Run(text: "a=b", bold: true)])
        #expect(try Self.runs(#"==a\=b=="#) == [Run(text: "a=b", highlighted: true)])
    }

    @Test("other escapes still work")
    func otherEscapes() throws {
        #expect(try Self.runs(#"\*not italic\* \\"#) == [Run(text: #"*not italic* \"#)])
    }

    @Test(
        "an unmatched marker stays literal",
        arguments: ["**unclosed bold", "*unclosed", "_unclosed", "~~unclosed", "==unclosed", "^^unclosed", ",{unclosed"]
    )
    func unmatchedMarkers(markdown: String) throws {
        #expect(try Self.runs(markdown) == [Run(text: markdown)])
    }

    @Test("formatting inside link text applies")
    func formattingInsideLink() throws {
        #expect(try Self.runs("[**bold** _it_ in link](https://www.airship.com)") == [
            Run(text: "bold", bold: true, link: Self.link),
            Run(text: " ", link: Self.link),
            Run(text: "it", italic: true, link: Self.link),
            Run(text: " in link", link: Self.link),
        ])
    }

    @Test("formatting around a link applies to it")
    func formattingAroundLink() throws {
        #expect(try Self.runs("**[bold _it_](https://www.airship.com)** after") == [
            Run(text: "bold ", bold: true, link: Self.link),
            Run(text: "it", bold: true, italic: true, link: Self.link),
            Run(text: " after"),
        ])
    }

    @Test("emphasis touching a link inside a word stays literal")
    func emphasisTouchingLinkInsideWord() throws {
        #expect(try Self.runs("foo**[x](https://www.airship.com)**bar") == [
            Run(text: "foo**"),
            Run(text: "x", link: Self.link),
            Run(text: "**bar"),
        ])
        #expect(try Self.runs("a *[x](https://www.airship.com)*b") == [
            Run(text: "a *"),
            Run(text: "x", link: Self.link),
            Run(text: "*b"),
        ])
    }

    @Test("a link after an escaped ! keeps the formatting in its text")
    func linkAfterEscapedBang() throws {
        #expect(try Self.runs(#"\![**b** c](https://www.airship.com)"#) == [
            Run(text: "!"),
            Run(text: "b", bold: true, link: Self.link),
            Run(text: " c", link: Self.link),
        ])
    }

    @Test("several links keep their own text and URLs")
    func severalLinks() throws {
        let other = URL(string: "https://example.com/a_(b)")!
        #expect(try Self.runs("[one](https://www.airship.com) and [two](https://example.com/a_(b) \"title\")") == [
            Run(text: "one", link: Self.link),
            Run(text: " and "),
            Run(text: "two", link: other),
        ])
    }

    @Test("bracketed text that isn't a link stays literal", arguments: [#"\[x](/docs)"#, "[x] (/docs)", "[x](/docs"])
    func notLinks(markdown: String) throws {
        #expect(try Self.runs(markdown).allSatisfy { $0.link == nil })
    }

    @Test("a span around a link colors the rest of its text but not the link")
    func spanAroundLink() throws {
        #expect(try Self.runs("[[link](https://www.airship.com) in color]{color:brand}") == [
            Run(text: "link", link: Self.link),
            Run(text: " in color", color: Self.brand),
        ])
    }

    @Test("a span inside link text doesn't recolor the link")
    func spanInsideLink() throws {
        #expect(try Self.runs("[[colored]{color:brand} in link](https://www.airship.com)") == [
            Run(text: "colored in link", link: Self.link),
        ])
    }

    @Test("the anchor color wins over a color span, around a link or inside its text")
    func anchorColorOverSpan() throws {
        let options = try JSONDecoder().decode(
            ThomasMarkDownOptions.self,
            from: Data(##"{"appearance": {"anchor": {"color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}}}}"##.utf8)
        )
        let anchor = try #require(options.appearance?.anchor?.color).toColor(Self.environment)

        for markdown in [
            "[[link](https://www.airship.com) in color]{color:brand}",
            "[[colored]{color:brand} in link](https://www.airship.com)",
        ] {
            let attributed = try Self.render(markdown, options: options)
            for run in attributed.runs {
                let expected = run.link != nil ? anchor : Self.brand
                #expect(run.attributes.swiftUI.foregroundColor == expected, "\(markdown)")
            }
        }
    }

    @Test("a link inside link text is the link, and the outer brackets are text")
    func nestedLinks() throws {
        let inner = URL(string: "https://x.com")!
        #expect(try Self.runs("[a [b](https://x.com)](/y)") == [
            Run(text: "[a "),
            Run(text: "b", link: inner),
            Run(text: "](/y)"),
        ])
    }

    @Test("deeply nested links keep only the innermost, without stalling", .timeLimit(.minutes(1)))
    func deeplyNestedLinks() throws {
        let depth = 40
        let markdown = String(repeating: "[a ", count: depth) + "[b](https://x.com)"
            + String(repeating: "](/y)", count: depth)
        let runs = try Self.runs(markdown)
        #expect(runs.filter { $0.link != nil }.map(\.text) == ["b"])
        #expect(runs.map(\.text).joined() == String(repeating: "[a ", count: depth) + "b"
            + String(repeating: "](/y)", count: depth))
    }

    @Test("a link's brackets read as punctuation beside markers in its text")
    func linkEdgesArePunctuation() throws {
        #expect(try Self.runs("[*a.**](https://www.airship.com)") == [Run(text: "*a.**", link: Self.link)])
        #expect(try Self.runs("[*a*](https://www.airship.com)") == [Run(text: "a", italic: true, link: Self.link)])
    }

    @Test("highlight, superscript and subscript apply inside link text")
    func delimitersInsideLink() throws {
        let runs = try Self.runs("[==mark== ^^up^^](https://www.airship.com)")
        #expect(runs.map(\.text) == ["mark", " ", "up"])
        #expect(runs.allSatisfy { $0.link == Self.link })
        #expect(runs.map(\.highlighted) == [true, false, false])
        #expect(runs[2].baselineOffset == Self.fontSize * 0.4)
    }

    @Test("nested superscript and subscript both apply", arguments: ["^^a,{b},^^", ",{b^^a^^},"])
    func nestedScripts(markdown: String) throws {
        let up = Self.fontSize * 0.4
        let down = -(Self.fontSize * 0.2)
        let runs = try Self.runs(markdown)
        let a = try #require(runs.first { $0.text == "a" })
        let b = try #require(runs.first { $0.text == "b" })
        #expect(a.baselineOffset == (markdown.hasPrefix("^^") ? up : up + down))
        #expect(b.baselineOffset == (markdown.hasPrefix("^^") ? up + down : down))
    }

    @Test("an escaped bracket is literal and never opens or closes a color span")
    func escapedBracketsInColorSpans() throws {
        #expect(try Self.runs(#"\[x]{color:brand}"#) == [Run(text: "[x]{color:brand}")])
        #expect(try Self.runs(#"[a\[]{color:brand} b"#) == [Run(text: "a[", color: Self.brand), Run(text: " b")])
        #expect(try Self.runs(#"[\]b]{color:brand}"#) == [Run(text: "]b", color: Self.brand)])
        #expect(try Self.runs(#"[\[tag\]]{color:brand}"#) == [Run(text: "[tag]", color: Self.brand)])
    }

    @Test("an escaped bracket in link text is part of the text")
    func escapedBracketInLinkText() throws {
        #expect(try Self.runs(#"[a\[ b\]](https://www.airship.com)"#) == [Run(text: "a[ b]", link: Self.link)])
    }

    @Test("link text that looks like a URL opens the link's own URL")
    func urlLikeLinkText() throws {
        let promo = URL(string: "https://www.airship.com/promo?utm=x")!
        #expect(try Self.runs("[www.airship.com](https://www.airship.com/promo?utm=x)") == [
            Run(text: "www.airship.com", link: promo),
        ])
        #expect(try Self.runs("[see https://example.com today](https://www.airship.com/promo?utm=x)") == [
            Run(text: "see https://example.com today", link: promo),
        ])
    }

    @Test("an escaped character beside emphasis reads as the punctuation it is")
    func escapeBesideEmphasis() throws {
        #expect(try Self.runs(#"\[_note_\]"#) == [Run(text: "["), Run(text: "note", italic: true), Run(text: "]")])
        #expect(try Self.runs(#"_x_\]"#) == [Run(text: "x", italic: true), Run(text: "]")])
        #expect(try Self.runs(#"\=**"x"**"#) == [Run(text: "="), Run(text: "\"x\"", bold: true)])
    }

    @Test("an icon font's private-use characters stay as typed beside markdown")
    func privateUseCharacters() throws {
        #expect(try Self.runs("\u{E002} \u{E000}\u{E001} Warning") == [Run(text: "\u{E002} \u{E000}\u{E001} Warning")])
        #expect(try Self.runs("\u{E100} icon [x](https://www.airship.com) y") == [
            Run(text: "\u{E100} icon "),
            Run(text: "x", link: Self.link),
            Run(text: " y"),
        ])
    }

    @Test("an HTML entity reference stays as typed", arguments: ["&amp;", "&copy; 2026", "&#65;", "&#x41;"])
    func entityReferences(markdown: String) throws {
        #expect(try Self.runs(markdown) == [Run(text: markdown)])
    }

    @Test("an ampersand in a plain-text URL stays in its link")
    func ampersandInPlainURL() throws {
        let url = URL(string: "https://www.airship.com/?a=1&b=2")!
        #expect(try Self.runs("see https://www.airship.com/?a=1&b=2") == [
            Run(text: "see "),
            Run(text: "https://www.airship.com/?a=1&b=2", link: url),
        ])
    }

    @Test("backticks are ordinary characters and markdown inside them still formats")
    func backticks() throws {
        #expect(try Self.runs("`code **x**`") == [
            Run(text: "`code "),
            Run(text: "x", bold: true),
            Run(text: "`"),
        ])
        #expect(try Self.runs(#"a \` b"#) == [Run(text: "a ` b")])
    }
}
