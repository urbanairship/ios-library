/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Checkbox: View {
    let model: CheckboxModel
    let constraints: ViewConstraints
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var checkboxState: CheckboxState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createToggle() -> some View {
        let isOn = Binding<Bool>(
            get: {
                self.checkboxState.selectedItems.contains(self.model.value)
            },
            set: {
                if $0 {
                    self.checkboxState.selectedItems.insert(self.model.value)
                } else {
                    self.checkboxState.selectedItems.remove(self.model.value)
                }
            }
        )

        let toggle = Toggle(isOn: isOn.animation()) {}

        switch self.model.style {
        case .checkboxStyle(let style):
            toggle.toggleStyle(
                AirshipCheckboxToggleStyle(
                    viewConstraints: self.constraints,
                    model: style,
                    colorScheme: colorScheme,
                    disabled: !formState.isFormInputEnabled
                )
            )
        case .switchStyle(let style):
            toggle.toggleStyle(
                AirshipSwitchToggleStyle(model: style, colorScheme: colorScheme, disabled: !formState.isFormInputEnabled)
            )
        }
    }

    var body: some View {
        let enabled =
            self.checkboxState.selectedItems.contains(self.model.value)
            || self.checkboxState.selectedItems.count
                < self.checkboxState.maxSelection
        createToggle()
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
            .accessible(self.model)
            .addSelectedTrait(self.checkboxState.selectedItems.contains(self.model.value))
            .formElement()
            .disabled(!enabled)
    }
}
