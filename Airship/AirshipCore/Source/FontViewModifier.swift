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
        content.font(UIFont.resolveFont(self.textAppearance))
    }
    
    private func resolveFont() -> Font {
        var font: Font
        let scaledSize = UIFontMetrics.default.scaledValue(for: self.textAppearance.fontSize)
        
        if let fontFamily = resolveFontFamily(
            families: self.textAppearance.fontFamilies
        ) {
            font = Font.custom(
                fontFamily,
                fixedSize: scaledSize
            )
        } else {
            font = Font.system(size: scaledSize)
        }
        
        if let styles = self.textAppearance.styles {
            if styles.contains(.bold) {
                font = font.bold()
            }
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }
    
    private func resolveFontFamily(families: [String]?) -> String? {
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
    
    static func resolveUIFont(
        _ textAppearance: ThomasTextAppearance
    ) -> UIFont {
        var font = UIFont()
        let scaledSize = UIFontMetrics.default.scaledValue(for: textAppearance.fontSize)
        
        if let fontFamily = resolveFontFamily(
            families: textAppearance.fontFamilies
        ) {
            font =
            UIFont(
                name: fontFamily,
                size: scaledSize
            )
            ?? UIFont()
        } else {
            font = UIFont.systemFont(
                ofSize: scaledSize
            )
        }
        
        if let styles = textAppearance.styles {
            if styles.contains(.bold) {
                font = font.bold()
            }
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
    }
    
    static func resolveFont(
        _ textAppearance: ThomasTextAppearance
    ) -> Font {
        var font: Font
        let scaledSize = UIFontMetrics.default.scaledValue(for: textAppearance.fontSize)
        
        if let fontFamily = resolveFontFamily(
            families: textAppearance.fontFamilies
        ) {
            font = Font.custom(
                fontFamily,
                size: scaledSize
            )
        } else {
            font = Font.system(size: scaledSize)
        }
        
        if let styles = textAppearance.styles {
            if styles.contains(.bold) {
                font = font.bold()
            }
            if styles.contains(.italic) {
                font = font.italic()
            }
        }
        return font
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
                    if !UIFont.fontNames(forFamilyName: lowerCased).isEmpty {
                        return family
                    }
                }
            }
        }
        return nil
    }
}
