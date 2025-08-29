/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct ScoreToggleLayout: View {
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var scoreState: ScoreState
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .scoreToggleLayout,
            thomasState: thomasState
        )
    }

    let info: ThomasViewInfo.ScoreToggleLayout
    let constraints: ViewConstraints

    private var isOnBinding: Binding<Bool> {
        return Binding<Bool>(
            get: {
                self.scoreState.selected?.identifier == self.info.properties.identifier
            },
            set: {
                if $0 {
                    self.scoreState.setSelected(
                        identifier: self.info.properties.identifier,
                        reportingValue: self.info.properties.reportingValue,
                        attributeValue: self.info.properties.attributeValue
                    )
                }
            }
        )
    }

    var body: some View {
        ToggleLayout(
            isOn: self.isOnBinding,
            onToggleOn: self.info.properties.onToggleOn,
            onToggleOff: self.info.properties.onToggleOff
        ) {
            ViewFactory.createView(
                self.info.properties.view,
                constraints: constraints
            )
        }
        .constraints(self.constraints)
        .thomasCommon(self.info, formInputID: self.info.properties.identifier)
        .accessible(
            self.info.accessible,
            associatedLabel: associatedLabel,
            hideIfDescriptionIsMissing: false
        )
        .formElement()
    }
}
