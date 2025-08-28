/* Copyright Airship and Contributors */


import SwiftUI

@MainActor
struct CheckboxToggleLayout: View {
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var checkboxState: CheckboxState
    @EnvironmentObject var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .checkboxToggleLayout,
            thomasState: thomasState
        )
    }

    let info: ThomasViewInfo.CheckboxToggleLayout
    let constraints: ViewConstraints

    private var isOnBinding: Binding<Bool> {
        self.checkboxState.makeBinding(
            identifier: info.properties.identifier,
            reportingValue: info.properties.reportingValue
        )
    }

    private var isEnabled: Bool {
        let isSelected = self.checkboxState.isSelected(
            identifier: info.properties.identifier
        )

        return isSelected || !self.checkboxState.isMaxSelectionReached
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
