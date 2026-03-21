/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory

    static let defaultHighlightColor: Color = Color(
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
            return Text(verbatim: info.resolveLabelString(thomasState: thomasState))
        }

        do {
            return try markdownText
        } catch {
            let resolved = info.resolveLabelString(thomasState: thomasState)
            AirshipLogger.error("Failed to parse markdown text \(error) text \(resolved)")
            return Text(verbatim: resolved)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if let icon = resolvedStartIcon {
                let size = scaledFontSize
                Icons.icon(info: icon.icon, colorScheme: colorScheme)
                    .frame(width: size, height: size)
                    .padding(.trailing, icon.space)
                    .accessibilityHidden(true)
            }

            if #available(iOS 26.0, visionOS 26.0, *) {
                self.textView
                    .textAppearance(resolvedTextAppearance, colorScheme: colorScheme)
                    .truncationMode(.tail)
                    .textRenderer(HighlightRenderer())
            } else {
                self.textView
                    .textAppearance(resolvedTextAppearance, colorScheme: colorScheme)
                    .truncationMode(.tail)
            }


            if let icon = resolvedEndIcon {
                // Add a spacer if we are not auto to push the icon to the edge
                if constraints.width != nil {
                    Spacer()
                }

                let size = scaledFontSize
                Icons.icon(info: icon.icon, colorScheme: colorScheme)
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
            vertical: self.constraints.height == nil
        )
        .thomasCommon(self.info)
        .accessible(self.info.accessible, associatedLabel: nil, hideIfDescriptionIsMissing: true)
        .accessibilityRole(self.info.properties.accessibilityRole)
        .onAppear {
            if self.info.properties.isAccessibilityAlert == true {
                let message = self.info.resolveLabelString(thomasState: self.thomasState)
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
    func resolveLabelString(thomasState: ThomasState) -> String {
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
                if let string = AirshipResources.localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = resolvedRef {
            if let string = AirshipResources.localizedString(key: ref) {
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
        let range: Range<AttributedString.Index>
        let isHighlight: Bool
        let isSuperscript: Bool
        let isSubscript: Bool
    }

    private struct DelimitedRange {
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

        // Build boundaries from both outer and inner edges so delimiter
        // characters form their own sub-segments and can be skipped.
        var boundarySet: [AttributedString.Index] = [start, end]
        for r in highlightRanges + superscriptRanges + subscriptRanges {
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
                subscriptRanges.contains   { $0.outer.contains(mid) && !$0.inner.contains(mid) }

            if isDelimiter { continue }

            let isHighlight   = highlightRanges.contains   { $0.inner.contains(mid) }
            let isSuperscript = superscriptRanges.contains { $0.inner.contains(mid) }
            let isSubscript   = subscriptRanges.contains   { $0.inner.contains(mid) }

            segments.append(
                Segment(
                    range: segStart..<segEnd,
                    isHighlight: isHighlight,
                    isSuperscript: isSuperscript,
                    isSubscript: isSubscript
                )
            )
        }

        return segments
    }

    private var markdownText: Text {
        get throws {
            let resolved = info.resolveLabelString(thomasState: thomasState)

            // Parse markdown into attributed
            let attributed = try AttributedString(
                markdown: resolved,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )

            let highlightOptions = self.info.properties.markdown?.appearance?.highlight
            let fontSize = scaledFontSize

            // Find format segments INSIDE the attributed string
            let segments = formatSegments(in: attributed)

            // Build Text by slicing
            var result: Text?

            for seg in segments {
                var slice = attributed[seg.range]
                let piece: Text

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
                            color: highlightOptions?.color?.toColor(colorScheme) ?? Self.defaultHighlightColor,
                            cornerRadius: cornerRadius
                        )
                        piece = Text(AttributedString(slice))
                            .customAttribute(highlight)
                    } else {
                        slice.backgroundColor = highlightOptions?.color?.toColor(colorScheme) ?? Self.defaultHighlightColor
                        piece = Text(AttributedString(slice))
                    }
                } else {
                    piece = Text(AttributedString(slice))
                }

                result = result.map { $0 + piece } ?? piece
            }

            return result ?? Text(attributed)
        }
    }
}

@available(iOS 18.0, *)
struct HighlightAttribute: TextAttribute {
    let color: Color
    let cornerRadius: CGFloat
}

@available(iOS 18.0, *)
struct HighlightRenderer: TextRenderer {
    struct Cluster {
        var rect: CGRect
        var attr: HighlightAttribute
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
