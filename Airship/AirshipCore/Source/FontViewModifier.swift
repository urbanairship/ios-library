/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct FontViewModifier: ViewModifier {
    let fontSize: Int?
    let fontFamilies: [String]?
    let textStyles: [TextStyle]?
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.applyFont(fontSize, fontFamilies, textStyles)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    
    @ViewBuilder
    internal func applyFont(_ fontSize: Int?, _ fontFamilies: [String]?, _ textStyles: [TextStyle]?) -> some View {
        if let fontSize = fontSize, let fontFamilies = fontFamilies, let textStyles = textStyles {
            self.font(resolveFont(families: fontFamilies, fontSize: fontSize, textStyles: textStyles))
        } else {
            self
        }
    }
    
    internal func resolveFont(families: [String]?, fontSize: Int, textStyles: [TextStyle]) -> Font {
        var font: Font
        if let fontFamily = resolveFontFamily(families: families) {
            font = Font.custom(fontFamily, size: CGFloat(fontSize))
        } else {
            font = Font.system(size: CGFloat(fontSize))
        }
    
        if (textStyles.contains(.bold)) {
            return font.bold()
        }
        else if (textStyles.contains(.italic)) {
            return font.italic()
        }
        
        return font
    }
    
    internal func resolveFontFamily(families: [String]?) -> String? {
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
    
    @ViewBuilder
    func airshipFont(_ fontSize: Int?, _ fontFamilies: [String]?, _ textStyles: [TextStyle]?) -> some View {
        if let fontSize = fontSize, let fontFamilies = fontFamilies {
            self.modifier(FontViewModifier(fontSize: fontSize, fontFamilies: fontFamilies, textStyles: textStyles))
        } else {
            self
        }
    }
}
