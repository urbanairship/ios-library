/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextAppearanceViewModifier: ViewModifier {
    let textAppearance: TextAppearanceModel
    @ViewBuilder
    func body(content: Content) -> some View {
        content.font(resolveFont())
    }
    
    private func resolveFont() -> Font {
        var font: Font
        if let fontFamily = resolveFontFamily(families: self.textAppearance.fontFamilies) {
            font = Font.custom(fontFamily, size: CGFloat(self.textAppearance.fontSize))
        } else {
            font = Font.system(size: CGFloat(self.textAppearance.fontSize))
        }
        
        if let styles = self.textAppearance.styles {
            if (styles.contains(.bold)) {
                font = font.bold()
            }
            if (styles.contains(.italic)) {
                font = font.italic()
            }
        }
        return font
    }
    
    private func resolveFontFamily(families: [String]?) -> String? {
        if let families = families {
            for family in families {
                let lowerCased = family.lowercased()
                
                switch (lowerCased) {
                case "serif":
                    return "Times New Roman"
                case "sans-serif":
                    return nil
                default:
                    if (!UIFont.fontNames(forFamilyName: lowerCased).isEmpty) {
                        return family
                    }
                }
            }
        }
        return nil
    }
    
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension Text {
    
    private func applyTextStyles(styles: [TextStyle]?) -> Text {
        var text = self
        if let styles = styles {
            if (styles.contains(.bold)) {
                text = text.bold()
            }
            
            if (styles.contains(.italic)) {
                text = text.italic()
            }
            
            if (styles.contains(.underlined)) {
                text = text.underline()
            }
        }
        return text
    }
    
    @ViewBuilder
    func textAppearance(_ textAppearance: TextAppearanceModel?) -> some View {
        if let textAppearance = textAppearance {
            self.applyTextStyles(styles: textAppearance.styles)
                .multilineTextAlignment(textAppearance.alignment?.toSwiftTextAlignment() ?? .center)
                .modifier(TextAppearanceViewModifier(textAppearance: textAppearance))
                .foreground(textAppearance.color)
        } else {
            self
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension UITextView {
    func textAppearance(_ textAppearance: TextAppearanceModel?, _ colorScheme: ColorScheme) -> UITextView {
        if let textAppearance = textAppearance {
            self.textAlignment = textAppearance.alignment?.toNSTextAlignment() ?? .center
            self.textColor = textAppearance.color.toColor(colorScheme).uiColor()
            self.font = resolveUIFont(textAppearance)
        }
        return self
    }
    
    func textModifyAppearance(_ textAppearance: TextAppearanceModel?) {
        underlineText(textAppearance)
    }
    
    func underlineText(_ textAppearance: TextAppearanceModel?) {
        if let textAppearance = textAppearance {
            if let styles = textAppearance.styles {
                if (styles.contains(.underlined)) {
                    let textRange = NSRange(location: 0, length: self.text.count)
                    let attributeString = NSMutableAttributedString(attributedString:
                                                                        self.attributedText)
                    attributeString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
                    self.attributedText = attributeString
                }
            }
        }
    }
    
    private func resolveUIFont(_ textAppearance: TextAppearanceModel) -> UIFont {
        var font = UIFont()
        if let fontFamily = resolveFontFamily(families: textAppearance.fontFamilies) {
            font = UIFont(name: fontFamily, size: CGFloat(textAppearance.fontSize)) ?? UIFont()
        } else {
            font = UIFont.systemFont(ofSize: CGFloat(textAppearance.fontSize))
        }
        
        if let styles = textAppearance.styles {
            if (styles.contains(.bold)) {
                font = font.bold()
            }
            if (styles.contains(.italic)) {
                font = font.italic()
            }
        }
        return font
    }
    
    func resolveFontFamily(families: [String]?) -> String? {
        if let families = families {
            for family in families {
                let lowerCased = family.lowercased()
                
                switch (lowerCased) {
                case "serif":
                    return "Times New Roman"
                case "sans-serif":
                    return nil
                default:
                    if (!UIFont.fontNames(forFamilyName: lowerCased).isEmpty) {
                        return family
                    }
                }
            }
        }
        return nil
    }
}

extension UIFont {
    func withTraits(traits:UIFontDescriptor.SymbolicTraits) -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UIFont(descriptor: descriptor!, size: 0) //size 0 means keep the size as it is
    }
    
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension Color {
 
    func uiColor() -> UIColor {

        if #available(iOS 14.0, tvOS 14.0, *) {
            return UIColor(self)
        }

        let components = self.components()
        return UIColor(red: components.r, green: components.g, blue: components.b, alpha: components.a)
    }

    private func components() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {

        let scanner = Scanner(string: self.description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0

        let result = scanner.scanHexInt64(&hexNumber)
        if result {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
        }
        return (r, g, b, a)
    }
}
