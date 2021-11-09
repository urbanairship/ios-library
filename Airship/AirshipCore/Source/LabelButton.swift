/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct LabelButton : View {

    /// Button model.
    let model: LabelButtonModel
    
    /// View constriants.
    let constraints: ViewConstraints
        
    var body: some View {
        Button(action: {}) {
            
            let labelConstraints = ViewConstraints(contentWidth: self.constraints.contentWidth,
                                                   contentHeight: self.constraints.contentHeight,
                                                   frameWidth: self.constraints.contentWidth,
                                                   frameHeight: self.constraints.contentHeight)
            
            Label(model: self.model.label, constraints: labelConstraints)
                .applyIf(self.constraints.contentHeight == nil) { view in
                    view.padding([.bottom, .top])
                }
                .applyIf(self.constraints.contentWidth == nil) { view in
                    view.padding([.leading, .trailing])
                }
                .background(self.model.backgroundColor)
                .border(self.model.border)
        }
        .constraints(constraints)
        .buttonClick(self.model.identifier, behaviors: self.model.clickBehaviors) // TODO: pass actions
        .enableButton(self.model.enableBehaviors)
        .buttonStyle(PlainButtonStyle())
    }
}
