/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct FontViewModifier: ViewModifier {
    let fontSize: Int?
    let fontFamilies: [String]?
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.applyFont(fontSize, fontFamilies)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    
    @ViewBuilder
    internal func applyFont(_ fontSize: Int?, _ fontFamilies: [String]?) -> some View {
        if let fontSize = fontSize, let fontFamilies = fontFamilies {
            self.font(resolveFont(families: fontFamilies, fontSize: fontSize))
        } else {
            self
        }
    }
    
    internal func resolveFont(families: [String]?, fontSize: Int) -> Font {
        if let fontFamily = resolveFontFamily(families: families) {
            return Font.custom(fontFamily, size: CGFloat(fontSize))
        } else {
            return Font.system(size: CGFloat(fontSize))
        }
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
    func airshipFont(_ fontSize: Int?, _ fontFamilies: [String]?) -> some View {
        if let fontSize = fontSize, let fontFamilies = fontFamilies {
            self.modifier(FontViewModifier(fontSize: fontSize, fontFamilies: fontFamilies))
        } else {
            self
        }
    }
}
