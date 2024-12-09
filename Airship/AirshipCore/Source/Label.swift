/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Text/Label view

struct Label: View {
    let info: ThomasViewInfo.Label

    /// View constraints.
    let constraints: ViewConstraints

    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme

    private var markdownText: Text {
        get throws {
            var text = try AttributedString(
                markdown: resolvedText,
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

    private var resolvedText: String {
        return ThomasPropertyOverride.resolveRequired(
            state: viewState,
            overrides: self.info.overrides?.text,
            defaultValue: self.info.properties.text
        )
    }

    private var textView: Text {

        guard
            self.info.properties.markdown?.disabled != true
        else {
            return Text(verbatim: resolvedText)
        }

        do {
            return try markdownText
        } catch {
            AirshipLogger.error("Failed to parse markdown text \(error) text \(resolvedText)")
            return Text(verbatim: resolvedText)
        }
    }

    var body: some View {
        self.textView
            .textAppearance(self.info.properties.textAppearance)
            .truncationMode(.tail)
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
            .accessible(self.info.accessible)
            .accessibilityRole(self.info.properties.accessibilityRole)
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
            return .h1
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
