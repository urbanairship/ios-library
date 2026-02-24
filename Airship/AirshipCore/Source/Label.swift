/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

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
        UIFontMetrics.default.scaledValue(
            for: self.info.properties.textAppearance.fontSize
        )
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
                #if !os(watchOS)
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
    private func highlightSegments(
        in attributed: AttributedString
    ) -> [(range: Range<AttributedString.Index>, isHighlight: Bool)] {

        let chars = attributed.characters
        typealias Index = AttributedString.Index  // same as CharacterView.Index

        struct Segment {
            let range: Range<Index>
            let isHighlight: Bool
        }

        var segments: [Segment] = []

        let end = chars.endIndex

        var searchStart: Index = chars.startIndex  // where the next "normal" segment starts
        var i: Index = chars.startIndex

        while i < end {
            let next = chars.index(after: i)
            guard next < end else { break }

            // Look for opening "=="
            if chars[i] == "=", chars[next] == "=" {
                let openStart = i
                let openEnd = chars.index(after: next) // first char *after* "=="

                // Prefix BEFORE ==...==
                if searchStart < openStart {
                    segments.append(
                        Segment(
                            range: searchStart..<openStart,
                            isHighlight: false
                        )
                    )
                }

                // Now search for the matching closing "=="
                var j = openEnd
                var foundClose = false

                while j < end {
                    let jNext = chars.index(after: j)
                    if jNext < end, chars[j] == "=", chars[jNext] == "=" {
                        // Found closing "=="
                        let closeStart = j
                        let closeEnd = chars.index(after: jNext) // after closing "=="

                        let innerStart = openEnd
                        let innerEnd = closeStart

                        if innerStart < innerEnd {
                            segments.append(
                                Segment(
                                    range: innerStart..<innerEnd,
                                    isHighlight: true
                                )
                            )
                        }

                        // Next "normal" segment will start AFTER the closing "=="
                        searchStart = closeEnd
                        i = closeEnd
                        foundClose = true
                        break
                    }

                    j = chars.index(after: j)
                }

                if !foundClose {
                    // No closing "==": treat the opening "==" as normal text
                    i = chars.index(after: i)
                }
            } else {
                i = next
            }
        }

        // Trailing text after the last highlight
        if searchStart < end {
            segments.append(
                Segment(
                    range: searchStart..<end,
                    isHighlight: false
                )
            )
        }

        return segments.map { ($0.range, $0.isHighlight) }
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

            // Find highlight segments INSIDE the attributed string
            let segments = highlightSegments(in: attributed)

            // Build Text by slicing
            var result: Text?

            for seg in segments {
                var slice = attributed[seg.range]
                let piece: Text

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

                result = (result == nil) ? piece : (result! + piece)
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
