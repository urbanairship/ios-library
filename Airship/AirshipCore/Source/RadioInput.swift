/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RadioInput: View {
    let info: ThomasViewInfo.RadioInput
    let constraints: ViewConstraints
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var radioInputState: RadioInputState
    @EnvironmentObject var thomasState: ThomasState

    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .radioInput,
            thomasState: thomasState
        )
    }
    private var isOnBinding: Binding<Bool> {
        return radioInputState.makeBinding(
            identifier: nil,
            reportingValue: info.properties.reportingValue,
            attributeValue: info.properties.attributeValue
        )
    }

    @ViewBuilder
    var body: some View {
        Toggle(isOn: self.isOnBinding.animation()) {}
            .thomasToggleStyle(
                self.info.properties.style,
                constraints: self.constraints
            )
            .constraints(constraints)
            .thomasCommon(self.info)
            .accessible(
                self.info.accessible,
                associatedLabel: associatedLabel,
                hideIfDescriptionIsMissing: false
            )
            .formElement()
    }
}
