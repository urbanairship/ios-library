/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextAppearanceViewModifier<Appearance: BaseTextAppearance>: ViewModifier {
    let textAppearance: Appearance

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
    func textAppearance<Appearance: BaseTextAppearance>(_ textAppearance: Appearance?) -> some View {
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

#if !os(watchOS)
@available(iOS 13.0.0, tvOS 13.0, *)
extension UITextView {
    func textAppearance<Appearance: BaseTextAppearance>(_ textAppearance: Appearance?,
                                                        _ colorScheme: ColorScheme) -> UITextView {
        if let textAppearance = textAppearance {
            self.textAlignment = textAppearance.alignment?.toNSTextAlignment() ?? .center
                self.textColor =
                textAppearance.color.toUIColor(colorScheme)
            self.font = resolveUIFont(textAppearance)
        }
        return self
    }
    
    func textModifyAppearance<Appearance: BaseTextAppearance>(_ textAppearance: Appearance?) {
        underlineText(textAppearance)
    }
    
    func underlineText<Appearance: BaseTextAppearance>(_ textAppearance: Appearance?) {
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
    
    private func resolveUIFont<Appearance: BaseTextAppearance>(_ textAppearance: Appearance) -> UIFont {
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
#endif

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
