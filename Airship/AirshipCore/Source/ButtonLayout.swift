/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button layout view.
struct ButtonLayout : View {

    let model: ButtonLayoutModel
    let constraints: ViewConstraints
    @Environment(\.layoutState) var layoutState

    init(model: ButtonLayoutModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    var body: some View {
        AirshipButton(
            identifier: self.model.identifier,
            reportingMetadata: self.model.reportingMetadata,
            description: self.model.contentDescription ?? self.model.localizedContentDescription?.localized ?? self.model.identifier,
            clickBehaviors: self.model.clickBehaviors,
            eventHandlers: self.model.eventHandlers,
            actions: self.model.actions,
            tapEffect: self.model.tapEffect
        ) {
            ViewFactory.createView(model: self.model.view, constraints: constraints)
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
    }
}
