/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct AirshipToggle: View {
    let info: ThomasViewInfo.Toggle
    let constraints: ViewConstraints

    @EnvironmentObject var formState: FormState
    @State private var isOn: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        createToggle()
            .constraints(self.constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
            .addSelectedTrait(isOn)
            .formElement()
            .onAppear {
                restoreFormState()
                updateValue(self.isOn)
            }
    }

    @ViewBuilder
    private func createToggle() -> some View {
        let binding = Binding<Bool>(
            get: { self.isOn },
            set: {
                self.isOn = $0
                self.updateValue($0)
            }
        )

        Toggle(isOn: binding.animation()) {}
            .thomasToggleStyle(
                self.info.properties.style,
                colorScheme: colorScheme,
                constraints: self.constraints,
                disabled: !formState.isFormInputEnabled
            )
    }

    private func updateValue(_ isOn: Bool) {
        let isValid = isOn || !(self.info.validation.isRequired ?? false)
        let data = FormInputData(
            self.info.properties.identifier,
            value: .toggle(isOn),
            attributeName: self.info.properties.attributeName,
            attributeValue: isOn ? self.info.properties.attributeValue : nil,
            isValid: isValid
        )

        self.formState.updateFormInput(data)
    }

    private func restoreFormState() {
        let formValue = self.formState.data.formValue(
            identifier: self.info.properties.identifier
        )

        guard case let .toggle(value) = formValue
        else {
            return
        }

        self.isOn = value
    }

}
