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
extension TextField {
    @ViewBuilder
    func textAppearance(_ textAppearance: TextAppearanceModel?) -> some View {
        if let textAppearance = textAppearance {
            self.multilineTextAlignment(textAppearance.alignment?.toSwiftTextAlignment() ?? .center)
                .modifier(TextAppearanceViewModifier(textAppearance: textAppearance))
                .foreground(textAppearance.color)
        } else {
            self
        }
    }
}

#if !os(tvOS)
@available(iOS 14.0.0, tvOS 14.0, *)
extension TextEditor {
    @ViewBuilder
    func textAppearance(_ textAppearance: TextAppearanceModel?) -> some View {
        if let textAppearance = textAppearance {
            self.multilineTextAlignment(textAppearance.alignment?.toSwiftTextAlignment() ?? .center)
                .modifier(TextAppearanceViewModifier(textAppearance: textAppearance))
                .foreground(textAppearance.color)
        } else {
            self
        }
    }
}
#endif
