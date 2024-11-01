/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
struct LabelButton : View {

    let model: LabelButtonModel
    let constraints: ViewConstraints
    @Environment(\.layoutState) var layoutState
    
    init(model: LabelButtonModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    var body: some View {
        AirshipButton(
            identifier: self.model.identifier,
            reportingMetadata: self.model.reportingMetadata,
            description: self.model.contentDescription ?? self.model.label.text,
            clickBehaviors: self.model.clickBehaviors,
            eventHandlers: self.model.eventHandlers,
            actions: self.model.actions,
            tapEffect: self.model.tapEffect
        ) {
            Label(model: self.model.label, constraints: constraints)
                .applyIf(self.constraints.height == nil) { view in
                    view.padding([.bottom, .top], 12)
                }
                .applyIf(self.constraints.width == nil) { view in
                    view.padding([.leading, .trailing], 12)
                }
                .background(
                    color: self.model.backgroundColor,
                    border: self.model.border
                )
                .accessible(self.model)
                .background(Color.airshipTappableClear)
        }
        .commonButton(self.model)
        .environment(
            \.layoutState,
             layoutState.override(
                buttonState: ButtonState(identifier: self.model.identifier)
             )
        )
        .accessibilityHidden(model.accessibilityHidden ?? false)
    }
}
