/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Text/Label view

struct Label: View {
    private let info: ThomasViewInfo.Label

    /// View constraints.
    private let constraints: ViewConstraints

    @EnvironmentObject private var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @Environment(\.thomasSelectorEnvironment) private var selectorEnvironment
    @Environment(\.sizeCategory) private var sizeCategory

    private static let defaultHighlightColor: Color = Color(
        red: 1.0,
        green: 0.84,
        blue: 0.04,
        opacity: 0.3
    )

    init(info: ThomasViewInfo.Label, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var scaledFontSize: Double {
        AirshipFont.scaledSize(self.info.properties.textAppearance.fontSize)
    }

    private var resolvedEndIcon: ThomasViewInfo.Label.LabelIcon? {
        return ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: self.info.overrides?.iconEnd,
            defaultValue: self.info.properties.iconEnd
        )
    }

    private var resolvedStartIcon: ThomasViewInfo.Label.LabelIcon? {
        return ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: self.info.overrides?.iconStart,
            defaultValue: self.info.properties.iconStart
        )
    }

    private var resolvedTextAppearance: ThomasTextAppearance {
        return ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: self.info.overrides?.textAppearance,
            defaultValue: self.info.properties.textAppearance
        )
    }

    private var textView: Text {
        guard
            self.info.properties.markdown?.disabled != true
        else {
            return Text(verbatim: info.resolveLabelString(thomasState: thomasState, localizer: thomasEnvironment.extensions.localizer))
        }

        do {
            return try markdownText
        } catch {
            let resolved = info.resolveLabelString(thomasState: thomasState, localizer: thomasEnvironment.extensions.localizer)
            AirshipLogger.error("Failed to parse markdown text \(error) text \(resolved)")
            return Text(verbatim: resolved)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if let icon = resolvedStartIcon {
                let size = scaledFontSize
                Icons.icon(info: icon.icon, selectorEnvironment: selectorEnvironment)
                    .frame(width: size, height: size)
                    .padding(.trailing, icon.space)
                    .accessibilityHidden(true)
            }

            if #available(iOS 26.0, visionOS 26.0, *) {
                self.textView
                    .textAppearance(resolvedTextAppearance, selectorEnvironment: selectorEnvironment)
                    .truncationMode(.tail)
                    .textRenderer(HighlightRenderer())
            } else {
                self.textView
                    .textAppearance(resolvedTextAppearance, selectorEnvironment: selectorEnvironment)
                    .truncationMode(.tail)
            }

            if let icon = resolvedEndIcon {
                let size = scaledFontSize
                Icons.icon(info: icon.icon, selectorEnvironment: selectorEnvironment)
                    .frame(width: size, height: size)
                    .padding(.leading, icon.space)
                    .accessibilityHidden(true)
            }
        }
        .constraints(
            constraints,
            alignment: self.info.properties.textAppearance.alignment?
                .toFrameAlignment()
                ?? Alignment.center
        )
        .fixedSize(
            horizontal: false,
            vertical: self.constraints.height == nil && !self.constraints.fillsProposedHeight
        )
        .thomasCommon(self.info)
        .accessible(self.info.accessible, associatedLabel: nil, hideIfDescriptionIsMissing: true)
        .accessibilityRole(self.info.properties.accessibilityRole)
        .onAppear {
            if self.info.properties.isAccessibilityAlert == true {
                let message = self.info.resolveLabelString(thomasState: self.thomasState, localizer: thomasEnvironment.extensions.localizer)
#if !os(watchOS) && !os(macOS)
                UIAccessibility.post(notification: .announcement, argument: message)
#endif
            }
        }
    }
}

extension ThomasTextAppearance.TextAlignement {
    func toFrameAlignment() -> Alignment {
        switch self {
        case .start:
            return Alignment.leading
        case .end:
            return Alignment.trailing
        case .center:
            return Alignment.center
        }
    }

    func toSwiftTextAlignment() -> SwiftUI.TextAlignment {
        switch self {
        case .start:
            return SwiftUI.TextAlignment.leading
        case .end:
            return SwiftUI.TextAlignment.trailing
        case .center:
            return SwiftUI.TextAlignment.center
        }
    }
}

extension View {
    fileprivate func headingLevel(_ int: Int) -> AccessibilityHeadingLevel {
        switch int {
        case 1:
            return .h1
        case 2:
            return .h2
        case 3:
            return .h3
        case 4:
            return .h4
        case 5:
            return .h5
        case 6:
            return .h6
        default:
            return .unspecified
        }
    }

    @ViewBuilder
    fileprivate func accessibilityRole(_ role: ThomasViewInfo.Label.AccessibilityRole?) -> some View  {
        switch role {
        case .heading(let level):
            self.accessibilityAddTraits(.isHeader)
                .accessibilityHeading(headingLevel(level))
        case .none:
            self
        }
    }
}

extension ThomasViewInfo.Label {
    @MainActor
    func resolveLabelString(thomasState: ThomasState, localizer: any ThomasLocalizer) -> String {
        let resolvedRefs = ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: overrides?.refs,
            defaultValue: properties.refs
        )

        let resolvedRef = ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: overrides?.ref,
            defaultValue: properties.ref
        )

        if let refs = resolvedRefs {
            for ref in refs {
                if let string = localizer.localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = resolvedRef {
            if let string = localizer.localizedString(key: ref) {
                return string
            }
        }

        return ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: overrides?.text,
            defaultValue: properties.text
        )
    }
}


extension Label {
    private static let scriptFontScale: Double = 0.65
    private static let superscriptBaselineScale: Double = 0.4
    private static let subscriptBaselineScale: Double = 0.2

    private struct Segment {
        fileprivate let range: Range<AttributedString.Index>
        fileprivate let isHighlight: Bool
        fileprivate let isSuperscript: Bool
        fileprivate let isSubscript: Bool
        fileprivate let colorName: String?
    }

    struct ColorSpan {
        let range: DelimitedRange
        let colorName: String
    }

    private static let colorSpanPrefix: [Character] = Array("{color:")

    /// Finds `[text]{color:name}` spans, innermost first when they nest.
    ///
    /// Runs on the parsed characters, so markdown inside the brackets is already applied.
    /// A backslash-escaped `\[` or `\]` is a stand-in here, so it never opens or closes a span.
    ///
    /// - Parameter chars: the characters of the parsed label.
    /// - Returns: each span's outer range (from `[` through `}`), inner range, and color name.
    static func findColorSpans(in chars: AttributedString.CharacterView) -> [ColorSpan] {
        var results: [ColorSpan] = []
        var openBrackets: [AttributedString.Index] = []
        let end = chars.endIndex
        var i = chars.startIndex

        while i < end {
            let next = chars.index(after: i)

            if chars[i] == "[" {
                openBrackets.append(i)
            } else if chars[i] == "]", let open = openBrackets.popLast() {
                var j = next
                var prefixMatched = true
                for expected in Self.colorSpanPrefix {
                    guard j < end, chars[j] == expected else {
                        prefixMatched = false
                        break
                    }
                    j = chars.index(after: j)
                }

                if prefixMatched {
                    let nameStart = j
                    while j < end, chars[j] != "}", Self.isColorNameCharacter(chars[j]) {
                        j = chars.index(after: j)
                    }

                    let innerStart = chars.index(after: open)
                    if j < end, chars[j] == "}", nameStart < j, innerStart < i {
                        let outerEnd = chars.index(after: j)
                        results.append(ColorSpan(
                            range: DelimitedRange(outer: open..<outerEnd, inner: innerStart..<i),
                            colorName: String(chars[nameStart..<j])
                        ))
                        i = outerEnd
                        continue
                    }
                }
            }

            i = next
        }

        return results
    }

    private static func isColorNameCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "-"
    }

    struct DelimitedRange {
        /// Full range including the delimiter characters themselves.
        let outer: Range<AttributedString.Index>
        /// Inner content range, excluding the delimiter characters.
        let inner: Range<AttributedString.Index>
    }

    private static func findDelimitedRanges(
        in chars: AttributedString.CharacterView,
        open: (Character, Character),
        close: (Character, Character)
    ) -> [DelimitedRange] {
        var results: [DelimitedRange] = []
        let end = chars.endIndex
        var i = chars.startIndex

        while i < end {
            let next = chars.index(after: i)
            guard next < end else { break }

            if chars[i] == open.0, chars[next] == open.1 {
                let outerStart = i
                let openEnd = chars.index(after: next)
                var j = openEnd
                var foundClose = false

                while j < end {
                    let jNext = chars.index(after: j)
                    if jNext < end, chars[j] == close.0, chars[jNext] == close.1 {
                        let innerStart = openEnd
                        let innerEnd = j
                        let outerEnd = chars.index(after: jNext)
                        if innerStart < innerEnd {
                            results.append(DelimitedRange(
                                outer: outerStart..<outerEnd,
                                inner: innerStart..<innerEnd
                            ))
                        }
                        i = outerEnd
                        foundClose = true
                        break
                    }
                    j = chars.index(after: j)
                }

                if !foundClose {
                    i = chars.index(after: i)
                }
            } else {
                i = next
            }
        }

        return results
    }

    private static func formatSegments(in attributed: AttributedString) -> [Segment] {
        let chars = attributed.characters
        let start = chars.startIndex
        let end = chars.endIndex

        let highlightRanges   = findDelimitedRanges(in: chars, open: ("=", "="), close: ("=", "="))
        let superscriptRanges = findDelimitedRanges(in: chars, open: ("^", "^"), close: ("^", "^"))
        let subscriptRanges   = findDelimitedRanges(in: chars, open: (",", "{"), close: ("}", ","))
        let colorSpans        = Self.findColorSpans(in: chars)

        // Build boundaries from both outer and inner edges so delimiter
        // characters form their own sub-segments and can be skipped.
        var boundarySet: [AttributedString.Index] = [start, end]
        for r in highlightRanges + superscriptRanges + subscriptRanges + colorSpans.map(\.range) {
            boundarySet.append(r.outer.lowerBound)
            boundarySet.append(r.inner.lowerBound)
            boundarySet.append(r.inner.upperBound)
            boundarySet.append(r.outer.upperBound)
        }
        let boundaries = boundarySet
            .sorted { $0 < $1 }
            .reduce(into: [AttributedString.Index]()) { result, idx in
                if result.last != idx { result.append(idx) }
            }

        var segments: [Segment] = []
        for idx in 0..<(boundaries.count - 1) {
            let segStart = boundaries[idx]
            let segEnd = boundaries[idx + 1]
            guard segStart < segEnd else { continue }

            // Use midpoint to determine which ranges contain this segment.
            let mid = chars.index(segStart, offsetBy: chars.distance(from: segStart, to: segEnd) / 2)

            // A segment is a "delimiter" if it falls inside an outer range but
            // outside that range's inner content — skip it so delimiters are invisible.
            let isDelimiter =
                highlightRanges.contains   { $0.outer.contains(mid) && !$0.inner.contains(mid) } ||
                superscriptRanges.contains { $0.outer.contains(mid) && !$0.inner.contains(mid) } ||
                subscriptRanges.contains   { $0.outer.contains(mid) && !$0.inner.contains(mid) } ||
                colorSpans.contains        { $0.range.outer.contains(mid) && !$0.range.inner.contains(mid) }

            if isDelimiter { continue }

            let isHighlight   = highlightRanges.contains   { $0.inner.contains(mid) }
            let isSuperscript = superscriptRanges.contains { $0.inner.contains(mid) }
            let isSubscript   = subscriptRanges.contains   { $0.inner.contains(mid) }
            // Spans are found innermost first, so a nested span's color wins.
            let colorName     = colorSpans.first { $0.range.inner.contains(mid) }?.colorName

            segments.append(
                Segment(
                    range: segStart..<segEnd,
                    isHighlight: isHighlight,
                    isSuperscript: isSuperscript,
                    isSubscript: isSubscript,
                    colorName: colorName
                )
            )
        }

        return segments
    }

    /// Applies an anchor appearance's color and underline to every link.
    ///
    /// - Parameters:
    ///   - anchor: the label's `markdown.appearance.anchor`; `nil` leaves links unstyled.
    ///   - attributed: the parsed label, updated in place.
    ///   - selectorEnvironment: picks the anchor color's selector.
    static func applyAnchorAppearance(
        _ anchor: ThomasMarkDownOptions.Appearance.Anchor?,
        to attributed: inout AttributedString,
        selectorEnvironment: ThomasSelectorEnvironment
    ) {
        guard let anchor else { return }

        let color = anchor.color?.toColor(selectorEnvironment)
        let isUnderlined = anchor.styles?.contains(.underlined) == true
        let linkRanges = attributed.runs[\.link].compactMap { link, range in link == nil ? nil : range }

        for range in linkRanges {
            if let color {
                attributed[range].foregroundColor = color
            }
            if isUnderlined {
                attributed[range].underlineStyle = Text.LineStyle.single
            }
        }
    }

    /// Returns the color a `[text]{color:name}` span names in the scene's `references.colors`.
    ///
    /// Unlike a color reference, an unknown name isn't drawn black: the span keeps the label's own color.
    ///
    /// - Parameters:
    ///   - name: the span's color name, or `nil` outside a span.
    ///   - selectorEnvironment: carries the scene's named colors and picks their selectors.
    /// - Returns: the color, or `nil` where there's no name or the scene doesn't define it.
    static func spanColor(named name: String?, in selectorEnvironment: ThomasSelectorEnvironment) -> Color? {
        guard let name else { return nil }
        return selectorEnvironment.colors[name]?.toColor(selectorEnvironment)
    }

    /// Colors every run that isn't a link, so links inside a color span keep their anchor styling.
    ///
    /// - Parameters:
    ///   - color: the span's resolved color.
    ///   - attributed: the span's text, updated in place.
    static func applySpanColor(_ color: Color, to attributed: inout AttributedString) {
        let plainRanges = attributed.runs[\.link].compactMap { link, range in link == nil ? range : nil }
        for range in plainRanges {
            attributed[range].foregroundColor = color
        }
    }

    private var markdownText: Text {
        get throws {
            let attributed = try Self.markdownAttributedString(
                info.resolveLabelString(thomasState: thomasState, localizer: thomasEnvironment.extensions.localizer),
                options: self.info.properties.markdown,
                textAppearance: resolvedTextAppearance,
                scaledFontSize: scaledFontSize,
                selectorEnvironment: selectorEnvironment
            )

            // A custom corner radius needs the highlight drawn by `HighlightRenderer` instead of a background color.
            if #available(iOS 18.0, visionOS 2.0, *),
               let cornerRadius = self.info.properties.markdown?.appearance?.highlight?.cornerRadius {
                return Self.roundedHighlightText(attributed, cornerRadius: cornerRadius)
            }
            return Text(attributed)
        }
    }

    /// Builds text whose highlights are drawn with rounded corners by `HighlightRenderer`.
    ///
    /// - Parameters:
    ///   - attributed: text from `markdownAttributedString`, whose highlights are background colors.
    ///   - cornerRadius: the highlight's corner radius.
    /// - Returns: the text, with each background color moved to a `HighlightAttribute`.
    @available(iOS 18.0, visionOS 2.0, *)
    private static func roundedHighlightText(_ attributed: AttributedString, cornerRadius: CGFloat) -> Text {
        var result: Text?
        for (color, range) in attributed.runs[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] {
            var slice = AttributedString(attributed[range])
            let piece: Text
            if let color {
                slice.backgroundColor = nil
                piece = Text(slice).customAttribute(HighlightAttribute(color: color, cornerRadius: cornerRadius))
            } else {
                piece = Text(slice)
            }
            result = result.map { $0 + piece } ?? piece
        }
        return result ?? Text(attributed)
    }

    /// Renders a label's markdown text as styled text, with highlights drawn as a background color.
    ///
    /// Supports standard inline markdown plus `==highlight==`, `^^superscript^^`, `,{subscript},` and
    /// `[text]{color:name}`. A backslash makes any markdown punctuation literal, an escaped bracket never
    /// opens or closes a color span, backticks are ordinary characters, HTML entity references draw as
    /// typed, and markdown inside link text applies: `[**a** b](u)` is a link whose "a" is bold.
    ///
    /// - Parameters:
    ///   - text: the resolved label text.
    ///   - options: the label's markdown options, for anchor and highlight appearance.
    ///   - textAppearance: the label's text appearance, for the superscript and subscript font.
    ///   - scaledFontSize: the label's font size after dynamic type, for superscript and subscript offsets.
    ///   - selectorEnvironment: resolves the anchor, highlight and span colors.
    /// - Returns: the styled text.
    static func markdownAttributedString(
        _ text: String,
        options: ThomasMarkDownOptions?,
        textAppearance: ThomasTextAppearance,
        scaledFontSize: Double,
        selectorEnvironment: ThomasSelectorEnvironment
    ) throws -> AttributedString {
        var attributed = try parseInlineMarkdown(protectLiterals(text))
        Self.applyAnchorAppearance(
            options?.appearance?.anchor,
            to: &attributed,
            selectorEnvironment: selectorEnvironment
        )

        let highlightColor = options?.appearance?.highlight?.color?.toColor(selectorEnvironment) ?? Self.defaultHighlightColor
        let segments = formatSegments(in: attributed)
        var result = segments.isEmpty ? attributed : AttributedString()

        for seg in segments {
            var slice = AttributedString(attributed[seg.range])

            if let color = Self.spanColor(named: seg.colorName, in: selectorEnvironment) {
                Self.applySpanColor(color, to: &slice)
            }

            if seg.isSuperscript || seg.isSubscript {
                // Nested superscript and subscript both apply, so their offsets add.
                var offset = 0.0
                if seg.isSuperscript { offset += scaledFontSize * Self.superscriptBaselineScale }
                if seg.isSubscript { offset -= scaledFontSize * Self.subscriptBaselineScale }
                slice.baselineOffset = offset
                slice.font = AirshipFont.resolveFont(
                    size: textAppearance.fontSize * Self.scriptFontScale,
                    families: textAppearance.fontFamilies,
                    weight: textAppearance.fontWeight,
                    isItalic: textAppearance.hasStyle(.italic),
                    isBold: textAppearance.hasStyle(.bold)
                )
            }

            if seg.isHighlight {
                slice.backgroundColor = highlightColor
            }

            result += slice
        }

        restoreLiterals(in: &result)
        return result
    }

    /// Returns the Unicode noncharacter `U+FDD0` plus `offset`.
    ///
    /// Stand-ins are noncharacters because no real text holds them, where a private-use character
    /// may be an icon font's glyph.
    ///
    /// - Parameter offset: 0 through 31.
    /// - Returns: the noncharacter.
    private static func nonCharacter(_ offset: UInt32) -> Character {
        // Valid scalars that Swift only rejects as `\u{}` literals.
        Character(Unicode.Scalar(0xFDD0 + offset)!)
    }

    /// Stand-ins for backslash-escaped `=`, `^`, `,`, `[` and `]`, so the delimiter and color span scans
    /// don't see them.
    private static let escapedLiterals: [Character: Character] = [
        "=": nonCharacter(0),
        "^": nonCharacter(1),
        ",": nonCharacter(2),
        "[": nonCharacter(3),
        "]": nonCharacter(4),
    ]

    /// The stand-in `parseInlineMarkdown` puts in place of every link; links are spliced back in order.
    private static let linkPlaceholder: Character = nonCharacter(31)

    /// Punctuation either side of every stand-in, since a noncharacter reads as a letter beside emphasis:
    /// `foo**[x](u)**bar` stays literal as it would beside the link's own `[` and `)`, and `\[_x_\]` is
    /// italic as it would be beside a `[`.
    private static let standInOpen: Character = "\u{2045}"
    private static let standInClose: Character = "\u{2046}"

    /// Returns whether `text` starts with an HTML entity reference such as `&amp;`, `&#65;` or `&#x41;`.
    ///
    /// - Parameter text: text starting at an `&`.
    /// - Returns: `true` for a named, decimal or hex reference closed by `;`.
    private static func startsWithEntityReference(_ text: Substring) -> Bool {
        var chars = text.dropFirst().makeIterator()
        guard let first = chars.next() else { return false }

        let isReferenceCharacter: (Character) -> Bool
        let maxLength: Int
        var length = 0
        if first == "#" {
            guard let marker = chars.next() else { return false }
            if marker == "x" || marker == "X" {
                isReferenceCharacter = \.isHexDigit
                maxLength = 6
            } else if marker.isASCII, marker.isNumber {
                isReferenceCharacter = { $0.isASCII && $0.isNumber }
                maxLength = 7
                length = 1
            } else {
                return false
            }
        } else if first.isASCII, first.isLetter {
            isReferenceCharacter = { $0.isASCII && ($0.isLetter || $0.isNumber) }
            maxLength = 32
            length = 1
        } else {
            return false
        }

        while let char = chars.next() {
            if char == ";" { return length > 0 }
            guard isReferenceCharacter(char), length < maxLength else { return false }
            length += 1
        }
        return false
    }

    /// Swaps escaped `=`, `^`, `,`, `[` and `]` for stand-ins and escapes every backtick and entity
    /// reference.
    ///
    /// The markdown parser drops the backslash, so without a stand-in `\==x==` would still highlight
    /// and `\[x]{color:brand}` would still color.
    /// Escaping backticks keeps the parser from making code spans, and escaping the `&` of an entity
    /// reference keeps `&amp;` as typed, as Android and web draw it. A bare `&` isn't escaped, since
    /// a backslash inside a plain-text URL would stay in its link.
    ///
    /// - Parameter text: the label's markdown.
    /// - Returns: markdown for `parseInlineMarkdown`; `restoreLiterals` undoes the stand-ins.
    private static func protectLiterals(_ text: String) -> String {
        var result = ""
        var isEscaped = false
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            defer { index = text.index(after: index) }
            if isEscaped {
                isEscaped = false
                if let standIn = escapedLiterals[char] {
                    result.append(standInOpen)
                    result.append(standIn)
                    result.append(standInClose)
                } else {
                    result.append("\\")
                    result.append(char)
                }
            } else if char == "\\" {
                isEscaped = true
            } else if char == "`" {
                result.append("\\`")
            } else if char == "&", startsWithEntityReference(text[index...]) {
                result.append("\\&")
            } else {
                result.append(char)
            }
        }
        if isEscaped { result.append("\\") }
        return result
    }

    /// Puts the escaped characters `protectLiterals` swapped out back in place, wrappers and all, keeping
    /// their styling.
    ///
    /// - Parameter attributed: the rendered text, updated in place.
    private static func restoreLiterals(in attributed: inout AttributedString) {
        let chars = attributed.characters
        guard chars.contains(where: { literals[$0] != nil }) else { return }

        var restored = AttributedString()
        var copied = chars.startIndex
        var index = chars.startIndex
        while index < chars.endIndex {
            guard let literal = literals[chars[index]] else {
                index = chars.index(after: index)
                continue
            }
            let after = chars.index(after: index)
            var start = index
            var end = after
            if index > copied, chars[chars.index(before: index)] == standInOpen,
               after < chars.endIndex, chars[after] == standInClose {
                start = chars.index(before: index)
                end = chars.index(after: after)
            }
            restored += AttributedString(attributed[copied..<start])
            let attributes = attributed[index..<after].runs.first?.attributes ?? AttributeContainer()
            restored += AttributedString(String(literal), attributes: attributes)
            copied = end
            index = end
        }
        restored += AttributedString(attributed[copied..<chars.endIndex])
        attributed = restored
    }

    /// Each stand-in, mapped back to the character it stands for.
    private static let literals: [Character: Character] = Dictionary(
        uniqueKeysWithValues: escapedLiterals.map { ($0.value, $0.key) }
    )

    private struct InlineLink {
        let label: String
        let url: URL
    }

    /// Parses inline markdown, applying the markdown inside each link's text.
    ///
    /// The system parser keeps only the link and drops any emphasis inside its text, so each link is swapped
    /// for a placeholder, its text parsed on its own, and the result spliced back with the link added and the
    /// placeholder's own emphasis kept: `**[a _b_](u)**` is a bold link whose "b" is also italic. All of a
    /// link's text takes its URL, so text that looks like a URL (`[www.a.com](u)`) still opens `u`.
    ///
    /// - Parameter markdown: markdown from `protectLiterals`.
    /// - Returns: the parsed text.
    private static func parseInlineMarkdown(_ markdown: String) throws -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let (source, links) = extractLinks(markdown)
        var attributed = try AttributedString(markdown: source, options: options)

        // Links splice back in order, so every placeholder has to have survived the parse.
        guard attributed.characters.filter({ $0 == linkPlaceholder }).count == links.count else {
            return try AttributedString(markdown: markdown, options: options)
        }

        for link in links {
            let chars = attributed.characters
            guard let index = chars.firstIndex(of: linkPlaceholder) else { continue }
            let after = chars.index(after: index)
            let start = index > chars.startIndex && chars[chars.index(before: index)] == standInOpen
                ? chars.index(before: index) : index
            let end = after < chars.endIndex && chars[after] == standInClose ? chars.index(after: after) : after
            let outerIntent = attributed[index..<after].runs.first?.inlinePresentationIntent ?? []

            var label = try parseLinkText(link.label)
            let runs = label.runs.map { ($0.range, $0.inlinePresentationIntent ?? []) }
            for (runRange, intent) in runs {
                let merged = intent.union(outerIntent)
                label[runRange].inlinePresentationIntent = merged.isEmpty ? nil : merged
                label[runRange].link = link.url
            }
            attributed.replaceSubrange(start..<end, with: label)
        }

        return attributed
    }

    /// Parses a link's text on its own, between the punctuation its `[` and `]` are to emphasis beside
    /// them: `[*a.**](u)` stays literal, as it does in the whole label.
    ///
    /// - Parameter text: the link's text, from `extractLinks`.
    /// - Returns: the parsed text.
    private static func parseLinkText(_ text: String) throws -> AttributedString {
        let parsed = try parseInlineMarkdown(String(standInOpen) + text + String(standInClose))
        let chars = parsed.characters
        guard chars.count >= 2, chars.first == standInOpen, chars.last == standInClose else { return parsed }
        return AttributedString(parsed[chars.index(after: chars.startIndex)..<chars.index(before: chars.endIndex)])
    }

    /// Replaces each inline link `[text](destination)` with `linkPlaceholder`, wrapped in
    /// `standInOpen` and `standInClose`.
    ///
    /// The text's brackets must balance; an escaped `\[`, an image `![`, or a `]` followed by anything but `(`
    /// isn't a link, so `[x]{color:name}` spans are left in place.
    ///
    /// - Parameter markdown: markdown from `protectLiterals`.
    /// - Returns: the markdown with placeholders, and each link's text and URL in order.
    private static func extractLinks(_ markdown: String) -> (String, [InlineLink]) {
        let chars = Array(markdown)
        let closes = closingBrackets(in: chars)
        var result = ""
        var links: [InlineLink] = []
        var i = 0
        var followsEscape = false

        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count {
                result.append(chars[i])
                result.append(chars[i + 1])
                i += 2
                followsEscape = true
                continue
            }

            // `\![x](u)` is a link after a literal "!", not an image.
            if chars[i] == "[",
               i == 0 || chars[i - 1] != "!" || followsEscape,
               let found = link(at: i, in: chars, closes: closes) {
                let (close, closeParen, url) = found
                let label = String(chars[(i + 1)..<close])
                // A link can't hold a link: the inner one is the link, and these brackets are text.
                if containsLink(chars, in: (i + 1)..<close, closes: closes), let bracket = escapedLiterals["["] {
                    result.append(standInOpen)
                    result.append(bracket)
                    result.append(standInClose)
                    i += 1
                    followsEscape = false
                    continue
                }
                links.append(InlineLink(label: label, url: url))
                result.append(standInOpen)
                result.append(linkPlaceholder)
                result.append(standInClose)
                i = closeParen + 1
                followsEscape = false
                continue
            }

            result.append(chars[i])
            i += 1
            followsEscape = false
        }

        return (result, links)
    }

    /// Returns where each `[` and `(` closes, by index, skipping escaped characters.
    ///
    /// - Parameter chars: the markdown's characters.
    /// - Returns: the index of each balanced opening bracket's closing one; an unbalanced one has none.
    private static func closingBrackets(in chars: [Character]) -> [Int: Int] {
        var closes: [Int: Int] = [:]
        var squares: [Int] = []
        var parens: [Int] = []
        var i = 0
        while i < chars.count {
            switch chars[i] {
            case "\\":
                i += 1
            case "[":
                squares.append(i)
            case "]":
                if let open = squares.popLast() { closes[open] = i }
            case "(":
                parens.append(i)
            case ")":
                if let open = parens.popLast() { closes[open] = i }
            default:
                break
            }
            i += 1
        }
        return closes
    }

    /// Returns the inline link whose `[` is at `start`: its text's closing `]`, its destination's
    /// closing `)`, and its URL.
    ///
    /// - Parameters:
    ///   - start: the index of a `[`.
    ///   - chars: the markdown's characters.
    ///   - closes: from `closingBrackets(in:)`.
    /// - Returns: the link, or `nil` when the `[` doesn't open one.
    private static func link(
        at start: Int,
        in chars: [Character],
        closes: [Int: Int]
    ) -> (close: Int, closeParen: Int, url: URL)? {
        guard
            let close = closes[start],
            close + 1 < chars.count, chars[close + 1] == "(",
            let closeParen = closes[close + 1],
            let url = linkURL(destination: String(chars[(close + 2)..<closeParen]))
        else { return nil }
        return (close, closeParen, url)
    }

    /// Returns whether link text holds a link of its own, read as `extractLinks` reads a label.
    ///
    /// Any link counts, not only one `extractLinks` would keep, since a link inside an inner link is
    /// still in the text. So it never recurses, and deeper nesting doesn't multiply the work.
    ///
    /// - Parameters:
    ///   - chars: the markdown's characters.
    ///   - range: the link text's range in `chars`.
    ///   - closes: from `closingBrackets(in:)`.
    /// - Returns: whether the text holds a link.
    private static func containsLink(
        _ chars: [Character],
        in range: Range<Int>,
        closes: [Int: Int]
    ) -> Bool {
        var i = range.lowerBound
        var followsEscape = false
        while i < range.upperBound {
            if chars[i] == "\\" {
                i += 2
                followsEscape = true
                continue
            }
            if chars[i] == "[",
               i == range.lowerBound || chars[i - 1] != "!" || followsEscape,
               let found = link(at: i, in: chars, closes: closes),
               found.closeParen < range.upperBound {
                return true
            }
            i += 1
            followsEscape = false
        }
        return false
    }

    /// Returns the URL the markdown parser gives a link destination, or `nil` if it isn't a valid one.
    ///
    /// - Parameter destination: the text between a link's parentheses, which may include a title.
    /// - Returns: the link's URL.
    private static func linkURL(destination: String) -> URL? {
        var original = ""
        for char in destination where char != standInOpen && char != standInClose {
            if let literal = literals[char] {
                original.append("\\")
                original.append(literal)
            } else {
                original.append(char)
            }
        }

        guard
            let parsed = try? AttributedString(
                markdown: "[x](\(original))",
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ),
            String(parsed.characters) == "x"
        else {
            return nil
        }
        return parsed.runs.first?.link
    }
}

@available(iOS 18.0, *)
struct HighlightAttribute: TextAttribute {
    fileprivate let color: Color
    fileprivate let cornerRadius: CGFloat
}

@available(iOS 18.0, *)
struct HighlightRenderer: TextRenderer {
    struct Cluster {
        fileprivate var rect: CGRect
        fileprivate var attr: HighlightAttribute
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            var clusters: [Cluster] = []
            var currentRect: CGRect?
            var currentAttr: HighlightAttribute?

            for run in line {
                if let highlight = run[HighlightAttribute.self] {
                    let runRect = run.typographicBounds.rect

                    if var rect = currentRect, let attr = currentAttr,
                       attr.color == highlight.color,
                       attr.cornerRadius == highlight.cornerRadius {
                        rect = rect.union(runRect)
                        currentRect = rect
                        currentAttr = highlight
                    } else {
                        // flush previous cluster
                        if let rect = currentRect, let attr = currentAttr {
                            clusters.append(Cluster(rect: rect, attr: attr))
                        }
                        currentRect = runRect
                        currentAttr = highlight
                    }
                } else {
                    // end of a cluster
                    if let rect = currentRect, let attr = currentAttr {
                        clusters.append(Cluster(rect: rect, attr: attr))
                        currentRect = nil
                        currentAttr = nil
                    }
                }
            }

            if let rect = currentRect, let attr = currentAttr {
                clusters.append(Cluster(rect: rect, attr: attr))
            }

            for cluster in clusters {
                let path = Path(
                    roundedRect: cluster.rect,
                    cornerRadius: cluster.attr.cornerRadius
                )
                context.fill(path, with: .color(cluster.attr.color))
            }

            for run in line {
                context.draw(run)
            }
        }
    }
}
