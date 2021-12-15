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
            Label(model: self.model.label, constraints: constraints)
                .applyIf(self.constraints.height == nil) { view in
                    view.padding([.bottom, .top], 12)
                }
                .applyIf(self.constraints.width == nil) { view in
                    view.padding([.leading, .trailing], 12)
                }
                .background(self.model.backgroundColor)
                .border(self.model.border)
                .viewAccessibility(label: self.model.contentDescription)
        }
        .buttonClick(self.model.identifier,
                     buttonDescription: self.model.contentDescription ?? self.model.label.text,
                     behaviors: self.model.clickBehaviors,
                     actions: self.model.actions)
        .enableButton(self.model.enableBehaviors)
        .buttonStyle(PlainButtonStyle())

    }
}
