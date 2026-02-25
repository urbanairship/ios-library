/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RadioInput: View {
    private let info: ThomasViewInfo.RadioInput
    private let constraints: ViewConstraints
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var radioInputState: RadioInputState
    @EnvironmentObject private var thomasState: ThomasState

    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    init(info: ThomasViewInfo.RadioInput, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

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
            .accessibilityRemoveTraits(.isSelected)
    }
}
