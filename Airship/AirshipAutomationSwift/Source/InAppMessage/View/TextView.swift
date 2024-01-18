/* Copyright Airship and Contributors */

import SwiftUI

struct TextView: View {
    let textInfo: InAppMessageTextInfo
    let textTheme: TextTheme

    var body: some View {
        Text(textInfo.text)
            .foregroundColor(textInfo.color?.color ?? Color.black) /// Should never default to black
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
            return .center /// Default alignment
        }
    }
}

extension View {
    func applyTextStyling(textInfo:InAppMessageTextInfo) -> some View {
        return self.modifier(TextStyleViewModifier(textInfo: textInfo))
    }
}

struct TextStyleViewModifier: ViewModifier {
    let textInfo: InAppMessageTextInfo

    @ViewBuilder
    func body(content: Content) -> some View {
        content.font(UIFont.resolve(self.textInfo))
    }
}

fileprivate extension UIFont {
    static func resolve(
        _ textInfo: InAppMessageTextInfo
    ) -> Font {
        var font: Font
        let scaledSize = UIFontMetrics.default.scaledValue(for: textInfo.size ?? 0)

        if let fontFamily = resolveFamily(
            families: textInfo.fontFamilies
        ) {
            font = Font.custom(
                fontFamily,
                size: scaledSize
            )
        } else {
            font = Font.system(size: scaledSize)
        }

        if let styles = textInfo.style {
            if styles.contains(.bold) {
                font = font.bold()
            }
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }

    static func resolveFamily(families: [String]?) -> String? {
        if let families = families {
            for family in families {
                let lowerCased = family.lowercased()

                switch lowerCased {
                case "serif":
                    return "Times New Roman"
                case "sans-serif":
                    return nil
                default:
                    if !UIFont.fontNames(forFamilyName: lowerCased).isEmpty {
                        return family
                    }
                }
            }
        }
        return nil
    }
}
