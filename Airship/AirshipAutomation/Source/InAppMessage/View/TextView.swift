/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct TextView: View {
    let textInfo: InAppMessageTextInfo
    let textTheme: InAppMessageTheme.Text

    var body: some View {
        Text(textInfo.text)
            .foregroundColor(textInfo.color?.color ?? .primary)
            .multilineTextAlignment(alignment(for: textInfo.alignment))
            .applyTextStyling(textInfo: textInfo)
            .applyTextTheme(textTheme)
    }

    private func alignment(for alignment: InAppMessageTextInfo.Alignment?) -> TextAlignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        case .none:
            return .center
        }
    }
}

extension View {
    func applyTextStyling(textInfo: InAppMessageTextInfo) -> some View {
        return self.modifier(TextStyleViewModifier(textInfo: textInfo))
    }
}

struct TextStyleViewModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let textInfo: InAppMessageTextInfo

    @ViewBuilder
    func body(content: Content) -> some View {
        content.font(
            AirshipFont.resolveFont(
                size: textInfo.size ?? 14,
                families: textInfo.fontFamilies,
                isItalic: textInfo.style?.contains(.italic) ?? false,
                isBold: textInfo.style?.contains(.bold) ?? false
            )
        )
    }
}
