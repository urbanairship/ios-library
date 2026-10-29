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
    /// Runs on the parsed characters, so markdown inside the brackets is already applied
    /// and a backslash-escaped `\[` still opens a span.
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

    private func findDelimitedRanges(
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

    private func formatSegments(in attributed: AttributedString) -> [Segment] {
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
            let resolved = info.resolveLabelString(thomasState: thomasState, localizer: thomasEnvironment.extensions.localizer)

            // Parse markdown into attributed
            var attributed = try AttributedString(
                markdown: resolved,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            Self.applyAnchorAppearance(
                self.info.properties.markdown?.appearance?.anchor,
                to: &attributed,
                selectorEnvironment: selectorEnvironment
            )

            let highlightOptions = self.info.properties.markdown?.appearance?.highlight
            let fontSize = scaledFontSize

            // Find format segments INSIDE the attributed string
            let segments = formatSegments(in: attributed)

            // Build Text by slicing
            var result: Text?

            for seg in segments {
                var slice = AttributedString(attributed[seg.range])
                let piece: Text

                if let color = Self.spanColor(named: seg.colorName, in: selectorEnvironment) {
                    Self.applySpanColor(color, to: &slice)
                }

                if seg.isSuperscript || seg.isSubscript {
                    slice.baselineOffset = seg.isSuperscript
                        ? fontSize * Self.superscriptBaselineScale
                        : -(fontSize * Self.subscriptBaselineScale)
                    slice.font = AirshipFont.resolveFont(
                        size: resolvedTextAppearance.fontSize * Self.scriptFontScale,
                        families: resolvedTextAppearance.fontFamilies,
                        weight: resolvedTextAppearance.fontWeight,
                        isItalic: resolvedTextAppearance.hasStyle(.italic),
                        isBold: resolvedTextAppearance.hasStyle(.bold)
                    )
                }

                if seg.isHighlight {
                    // For custom cornerRadius we have to use a custom attribute and renderer
                    if #available(iOS 18.0, visionOS 2.0, *), let cornerRadius = highlightOptions?.cornerRadius {
                        let highlight = HighlightAttribute(
                            color: highlightOptions?.color?.toColor(selectorEnvironment) ?? Self.defaultHighlightColor,
                            cornerRadius: cornerRadius
                        )
                        piece = Text(slice)
                            .customAttribute(highlight)
                    } else {
                        slice.backgroundColor = highlightOptions?.color?.toColor(selectorEnvironment) ?? Self.defaultHighlightColor
                        piece = Text(slice)
                    }
                } else {
                    piece = Text(slice)
                }

                result = result.map { $0 + piece } ?? piece
            }

            return result ?? Text(attributed)
        }
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
