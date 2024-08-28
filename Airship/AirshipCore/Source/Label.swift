/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Text/Label view

struct Label: View {
    /// Label model.
    let model: LabelModel

    /// View constraints.
    let constraints: ViewConstraints

    @Environment(\.colorScheme) var colorScheme

    @available(iOS 15, tvOS 15, watchOS 8, *)
    private var markdownText: Text {
        get throws {
            var text = try AttributedString(markdown: self.model.text)

            let anchorAppearance = self.model.markdown?.appearance?.anchor
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

    private var text: Text {
        guard 
            self.model.markdown?.disabled != true,
            #available(iOS 15, tvOS 15, watchOS 8, *)
        else {
            return Text(verbatim: self.model.text)
        }

        do {
            return try markdownText
        } catch {
            AirshipLogger.error("Failed to parse markdown text \(error) text \(self.model.text)")
            return Text(verbatim: self.model.text)
        }
    }

    var body: some View {
        self.text
            .textAppearance(self.model.textAppearance)
            .truncationMode(.tail)
            .constraints(
                constraints,
                alignment: self.model.textAppearance.alignment?
                    .toFrameAlignment()
                    ?? Alignment.center
            )
            .fixedSize(
                horizontal: false,
                vertical: self.constraints.height == nil
            )
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .accessible(self.model)
    }
}


extension TextAlignement {
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
