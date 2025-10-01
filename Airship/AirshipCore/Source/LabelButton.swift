/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
struct LabelButton : View {

    let info: ThomasViewInfo.LabelButton
    let constraints: ViewConstraints
    @Environment(\.layoutState) var layoutState
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .labelButton,
            thomasState: thomasState
        )
    }

    init(info: ThomasViewInfo.LabelButton, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        AirshipButton(
            identifier: self.info.properties.identifier,
            reportingMetadata: self.info.properties.reportingMetadata,
            description: self.info.accessible.contentDescription ?? self.info.properties.label.properties.text,
            clickBehaviors: self.info.properties.clickBehaviors,
            eventHandlers: self.info.commonProperties.eventHandlers,
            actions: self.info.properties.actions,
            tapEffect: self.info.properties.tapEffect
        ) {
            Label(
                info: self.info.properties.label,
                constraints: ViewConstraints()
            )
            .airshipApplyIf(self.constraints.height == nil) { view in
                view.padding([.bottom, .top], 12)
            }
            .airshipApplyIf(self.constraints.width == nil) { view in
                view.padding([.leading, .trailing], 12)
            }
            .constraints(constraints)
            .thomasCommon(info, scope: [.background])
            .accessible(
                self.info.accessible,
                associatedLabel: associatedLabel,
                hideIfDescriptionIsMissing: false
            )
            .background(Color.airshipTappableClear)
        }
        .thomasCommon(info, scope: [.enableBehaviors, .visibility])
        .environment(
            \.layoutState,
             layoutState.override(
                buttonState: ButtonState(identifier: self.info.properties.identifier)
             )
        )
        .accessibilityHidden(info.accessible.accessibilityHidden ?? false)
    }
}
