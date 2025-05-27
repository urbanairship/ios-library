/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct Checkbox: View {
    let info: ThomasViewInfo.Checkbox
    let constraints: ViewConstraints
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var checkboxState: CheckboxState

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
            .accessible(self.info.accessible)
            .formElement()
            .disabled(!self.isEnabled)
    }
}
