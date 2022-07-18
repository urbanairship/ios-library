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
            .textAppearance(self.model.textAppearance)
            .truncationMode(.tail)
            .constraints(constraints, alignment: self.model.textAppearance.alignment?.toFrameAlignment() ?? Alignment.center)
            .fixedSize(horizontal: false, vertical: self.constraints.height == nil)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .accessible(self.model)
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
    
    func toNSTextAlignment() -> NSTextAlignment {
        switch(self) {
        case .start:
            return .left
        case .end:
            return .right
        case .center:
            return .center
        }
    }
}
