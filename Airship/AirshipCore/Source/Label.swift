/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Text/Label view

struct Label: View {
    let info: ThomasViewInfo.Label

    /// View constraints.
    let constraints: ViewConstraints

    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory

    private var scaledFontSize: Double {
        UIFontMetrics.default.scaledValue(
            for: self.info.properties.textAppearance.fontSize
        )
    }
    
    private var markdownText: Text {
        get throws {
            var text = try AttributedString(
                markdown: info.resolveLabelString(thomasState: thomasState),
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )

            let anchorAppearance = self.info.properties.markdown?.appearance?.anchor
            let anchorColor = anchorAppearance?.color?.toColor(self.colorScheme)
            // Currently we only support underlined styles
            let underline = anchorAppearance?.styles?.contains(.underlined) ?? false

            text.runs.filter { run in
                run.link != nil
            }.forEach { run in
                text[run.range].foregroundColor = anchorColor
                if underline {
                    text[run.range].underlineStyle = .single
                }
            }

            return Text(text)
        }
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

            self.textView
                .textAppearance(resolvedTextAppearance, colorScheme: colorScheme)
                .truncationMode(.tail)


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

    func toNSTextAlignment() -> NSTextAlignment {
        switch self {
        case .start:
            return .left
        case .end:
            return .right
        case .center:
            return .center
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
