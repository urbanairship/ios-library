/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button layout view.
struct ButtonLayout : View {
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning

    let model: ButtonLayoutModel
    let constraints: ViewConstraints
    @Environment(\.layoutState) var layoutState

    init(model: ButtonLayoutModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    private var isButtonForAccessibility: Bool {
        guard let role = model.accessibilityRole else {
            // Default to button
            return true
        }

        return switch(role) {
        case .container:
            false
        case .button:
            true
        }
    }

    var body: some View {
        if isVoiceOverRunning, !isButtonForAccessibility {
            ViewFactory.createView(model: self.model.view, constraints: constraints)
                .background(
                    color: self.model.backgroundColor,
                    border: self.model.border
                )
                .accessibilityHidden(model.accessibilityHidden ?? false)
        } else {
            AirshipButton(
                identifier: self.model.identifier,
                reportingMetadata: self.model.reportingMetadata,
                description: self.model.contentDescription ?? self.model.localizedContentDescription?.localized,
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
}
