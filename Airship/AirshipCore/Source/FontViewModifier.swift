/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct TextAppearanceViewModifier: ViewModifier
{
    let textAppearance: ThomasTextAppearance

    // Needed for dynamic font size
    @Environment(\.sizeCategory) var sizeCategory
    
    @ViewBuilder
    func body(content: Content) -> some View {
        let baseFontSize = textAppearance.fontSize
        let scaledFontSize = UIFontMetrics.default.scaledValue(for: baseFontSize)
        let scaleFactor = Double(scaledFontSize) / baseFontSize
        content
            .font(Font.resolveFont(self.textAppearance))
            .applyLineHeightMultiplier(textAppearance.lineHeightMultiplier, scaledFontSize: scaledFontSize)
            .applyKerning(textAppearance.kerning, scaleFactor: scaleFactor)
    }
    
    private func resolveFont() -> Font {
        var font: Font
        let scaledSize = UIFontMetrics.default.scaledValue(for: self.textAppearance.fontSize)
        
        // Determine font weight
        // If fontWeight is explicitly provided, use it. Otherwise, if bold style is present, use 700.
        let fontWeight: Font.Weight
        if let weightValue = self.textAppearance.fontWeight {
            let roundedWeight = Font.roundFontWeight(weightValue)
            fontWeight = Font.weight(from: roundedWeight)
        } else if let styles = self.textAppearance.styles, styles.contains(.bold) {
            fontWeight = .bold
        } else {
            fontWeight = .regular
        }
        
        if let fontFamily = Font.resolveFontFamily(
            families: self.textAppearance.fontFamilies
        ) {
            font = Font.custom(
                fontFamily,
                fixedSize: scaledSize
            )
            .weight(fontWeight)
        } else {
            font = Font.system(size: scaledSize, weight: fontWeight)
        }
        
        if let styles = self.textAppearance.styles {
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }

}

extension Text {
    
    private func applyTextStyles(styles: [ThomasTextAppearance.TextStyle]?) -> Text {
        var text = self
        if let styles = styles {
            if styles.contains(.bold) {
                text = text.bold()
            }
            
            if styles.contains(.italic) {
                text = text.italic()
            }
            
            if styles.contains(.underlined) {
                text = text.underline()
            }
        }
        return text
    }
    
    @ViewBuilder
    @MainActor
    func textAppearance(
        _ textAppearance: ThomasTextAppearance?,
        colorScheme: ColorScheme
    ) -> some View {
        if let textAppearance = textAppearance {
            self.applyTextStyles(styles: textAppearance.styles)
                .multilineTextAlignment(
                    textAppearance.alignment?.toSwiftTextAlignment() ?? .center
                )
                .modifier(
                    TextAppearanceViewModifier(textAppearance: textAppearance)
                )
                .foreground(textAppearance.color, colorScheme: colorScheme)
        } else {
            self
        }
    }
}

extension View {

    @ViewBuilder
    @MainActor
    func applyLineHeightMultiplier(
        _ multiplier: Double?,
        scaledFontSize: Double
    ) -> some View {
        if let multiplier {
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                self.lineHeight(.multiple(factor: multiplier))
            } else {
                // Fallback: approximate using scaled font size as base line height.
                //
                // Natural line height ~= scaledFontSize * (font's internal multiplier).
                // We don't know that exact internal multiplier in SwiftUI,
                // but using scaledFontSize as the "1.0" baseline is a reasonable approximation.
                let baseLineHeight = scaledFontSize
                let effective = baseLineHeight * multiplier
                let extra = max(effective - baseLineHeight, 0)
                self.lineSpacing(extra)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    @MainActor
    fileprivate func applyKerning(
        _ kerning: Double?,
        scaleFactor: Double
    ) -> some View {
        if let kerning {
            self.kerning(kerning * scaleFactor)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyViewAppearance(
        _ textAppearance: ThomasTextAppearance?,
        colorScheme: ColorScheme
    ) -> some View {
        if let textAppearance = textAppearance {
            self
                .multilineTextAlignment(
                    textAppearance.alignment?.toSwiftTextAlignment() ?? .center
                )
                .modifier(
                    TextAppearanceViewModifier(textAppearance: textAppearance)
                )
                .foreground(textAppearance.color, colorScheme: colorScheme)
        } else {
            self
        }
    }
}

extension Font {
    /// Rounds font weight to nearest hundred and clamps to valid range [100, 900]
    static func roundFontWeight(_ fontWeight: Double) -> Int {
        // Round to nearest hundred
        let rounded = Int(round(fontWeight / 100.0) * 100.0)
        
        // Clamp to valid range [100, 900]
        if rounded < 100 {
            return 100
        } else if rounded > 900 {
            return 900
        }
        
        return rounded
    }
    
    /// Maps rounded font weight (100-900) to SwiftUI Font.Weight
    static func weight(from roundedWeight: Int) -> Font.Weight {
        switch roundedWeight {
        case 100:
            return .ultraLight
        case 200:
            return .thin
        case 300:
            return .light
        case 400:
            return .regular
        case 500:
            return .medium
        case 600:
            return .semibold
        case 700:
            return .bold
        case 800:
            return .heavy
        case 900:
            return .black
        default:
            // Fallback to regular for any edge cases
            return .regular
        }
    }
    
    static func resolveFontFamily(families: [String]?) -> String? {
        if let families = families {
            for family in families {
                let lowerCased = family.lowercased()

                switch lowerCased {
                case "serif":
                    return "Times New Roman"
                case "sans-serif":
                    return nil
                default:
                    // Check original case first
                    if !UIFont.fontNames(forFamilyName: family).isEmpty {
                        return family
                    }
                    // Fallback to lowercased check
                    if !UIFont.fontNames(forFamilyName: lowerCased).isEmpty {
                        return family
                    }
                }
            }
        }
        return nil
    }

    static func resolveFont(
        _ textAppearance: ThomasTextAppearance
    ) -> Font {
        var font: Font
        let scaledSize = UIFontMetrics.default.scaledValue(for: textAppearance.fontSize)
        
        // Determine font weight
        // If fontWeight is explicitly provided, use it. Otherwise, if bold style is present, use 700.
        let fontWeight: Font.Weight
        if let weightValue = textAppearance.fontWeight {
            let roundedWeight = roundFontWeight(weightValue)
            fontWeight = weight(from: roundedWeight)
        } else if let styles = textAppearance.styles, styles.contains(.bold) {
            fontWeight = .bold
        } else {
            fontWeight = .regular
        }

        if let fontFamily = resolveFontFamily(
            families: textAppearance.fontFamilies
        ) {
            font = Font.custom(
                fontFamily,
                fixedSize: scaledSize
            )
            .weight(fontWeight)
        } else {
            font = Font.system(size: scaledSize, weight: fontWeight)
        }

        if let styles = textAppearance.styles {
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }
}

extension UIFont {
    
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: 0)  //size 0 means keep the size as it is
        } else {
            return self
        }
    }
    
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
    
    /// Maps rounded font weight (100-900) to UIFont.Weight
    static func uiFontWeight(from roundedWeight: Int) -> UIFont.Weight {
        switch roundedWeight {
        case 100:
            return .ultraLight
        case 200:
            return .thin
        case 300:
            return .light
        case 400:
            return .regular
        case 500:
            return .medium
        case 600:
            return .semibold
        case 700:
            return .bold
        case 800:
            return .heavy
        case 900:
            return .black
        default:
            // Fallback to regular for any edge cases
            return .regular
        }
    }
    
    static func resolveUIFont(
        _ textAppearance: ThomasTextAppearance
    ) -> UIFont {
        var font: UIFont
        let scaledSize = UIFontMetrics.default.scaledValue(for: textAppearance.fontSize)
        
        // Determine font weight
        // If fontWeight is explicitly provided, use it. Otherwise, if bold style is present, use 700.
        let fontWeight: UIFont.Weight
        if let weightValue = textAppearance.fontWeight {
            let roundedWeight = Font.roundFontWeight(weightValue)
            fontWeight = uiFontWeight(from: roundedWeight)
        } else if let styles = textAppearance.styles, styles.contains(.bold) {
            fontWeight = .bold
        } else {
            fontWeight = .regular
        }
        
        if let fontFamily = Font.resolveFontFamily(
            families: textAppearance.fontFamilies
        ) {
            font =
            UIFont(
                name: fontFamily,
                size: scaledSize
            )
            ?? UIFont.systemFont(ofSize: scaledSize, weight: fontWeight)
        } else {
            font = UIFont.systemFont(
                ofSize: scaledSize,
                weight: fontWeight
            )
        }
        
        if let styles = textAppearance.styles {
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }
}

