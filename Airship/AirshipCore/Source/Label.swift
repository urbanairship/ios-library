/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


/// Text/Label view
@available(iOS 13.0.0, tvOS 13.0, *)
struct Label : View {
    /// Label model.
    let model: LabelModel
    
    /// View constriants.
    let constraints: ViewConstraints

    var body: some View {
        var text = Text(self.model.text)
            .font(Label.resolveFont(families: self.model.fontFamilies,
                                    fontSize: self.model.fontSize))
        
        if let textStyles = self.model.textStyles {
            if (textStyles.contains(.bold)) {
                text = text.bold()
            }
            if (textStyles.contains(.italic)) {
                text = text.italic()
            }
            if (textStyles.contains(.underline)) {
                text = text.underline()
            }
        }
        
        return text
            .multilineTextAlignment(self.model.alignment?.toSwiftTextAlignment() ?? .center)
            .frame(maxWidth: constraints.width,
                   maxHeight: constraints.height,
                   alignment: self.model.alignment?.toFrameAlignment() ?? Alignment.center)
            .foreground(model.foregroundColor)
            .background(model.backgroundColor)
    }
    
    private static func resolveFont(families: [String]?, fontSize: Int) -> Font {
        
        if let fontFamily = resolveFontFamily(families: families) {
            return Font.custom(fontFamily, size: CGFloat(fontSize))
        } else {
            return Font.system(size: CGFloat(fontSize))
        }
    }
    
    private static func resolveFontFamily(families: [String]?) -> String? {
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
internal extension TextAlignement {
    func toFrameAlignment() -> Alignment {
        switch(self) {
        case .start:
            return Alignment.leading
        case .end:
            return Alignment.trailing
        case .center:
            return Alignment.center
        }
    }
    
    func toSwiftTextAlignment() -> SwiftUI.TextAlignment {
        switch(self) {
        case .start:
            return SwiftUI.TextAlignment.leading
        case .end:
            return SwiftUI.TextAlignment.trailing
        case .center:
            return SwiftUI.TextAlignment.center
        }
    }
}
