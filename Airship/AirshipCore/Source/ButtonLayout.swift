/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button layout view.
struct ButtonLayout : View {
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning
    @Environment(\.layoutState) var layoutState

    let info: ThomasViewInfo.ButtonLayout
    let constraints: ViewConstraints

    init(info: ThomasViewInfo.ButtonLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var isButtonForAccessibility: Bool {
        guard let role = info.properties.accessibilityRole else {
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
            ViewFactory.createView(self.info.properties.view, constraints: constraints)
                .thomasCommon(self.info, scope: [.background, .visibility])
                .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
        } else {
            AirshipButton(
                identifier: self.info.properties.identifier,
                reportingMetadata: self.info.properties.reportingMetadata,
                description: self.info.accessible.resolveContentDescription,
                clickBehaviors: self.info.properties.clickBehaviors,
                eventHandlers: self.info.commonProperties.eventHandlers,
                actions: self.info.properties.actions,
                tapEffect: self.info.properties.tapEffect
            ) {
                ViewFactory.createView(self.info.properties.view, constraints: constraints)
                    .thomasCommon(self.info, scope: [.background])
                    .background(Color.airshipTappableClear)
            }
            .thomasCommon(self.info, scope: [.enableBehaviors, .visibility])
            .environment(
                \.layoutState,
                 layoutState.override(
                    buttonState: ButtonState(identifier: self.info.properties.identifier)
                 )
            )
            .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
        }
    }
}
