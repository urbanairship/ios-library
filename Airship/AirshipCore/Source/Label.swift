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
        Text(self.model.text)
            .textStyles(self.model.textStyles)
            .airshipFont(self.model.fontSize, self.model.fontFamilies)
            .multilineTextAlignment(self.model.alignment?.toSwiftTextAlignment() ?? .center)
            .frame(maxWidth: constraints.width,
                   maxHeight: constraints.height,
                   alignment: self.model.alignment?.toFrameAlignment() ?? Alignment.center)
            .foreground(model.foregroundColor)
            .background(model.backgroundColor)
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
