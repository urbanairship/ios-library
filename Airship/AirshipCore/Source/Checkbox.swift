/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct Checkbox: View {
    private let info: ThomasViewInfo.Checkbox
    private let constraints: ViewConstraints
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var checkboxState: CheckboxState
    @EnvironmentObject private var thomasState: ThomasState

    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    init(info: ThomasViewInfo.Checkbox, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .checkbox,
            thomasState: thomasState
        )
    }

    private var isOnBinding: Binding<Bool> {
        self.checkboxState.makeBinding(
            identifier: nil,
            reportingValue: info.properties.reportingValue
        )
    }

    private var isEnabled: Bool {
        let isSelected = self.checkboxState.isSelected(
            reportingValue: info.properties.reportingValue
        )

        return isSelected || !self.checkboxState.isMaxSelectionReached
    }

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
            .disabled(!self.isEnabled)
    }
}
