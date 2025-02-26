/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct AirshipToggle: View {
    let info: ThomasViewInfo.Toggle
    let constraints: ViewConstraints

    @EnvironmentObject var formState: ThomasFormState
    @State private var isOn: Bool = false

    var body: some View {
        createToggle()
            .constraints(self.constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
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
                constraints: self.constraints
            )
    }

    private var attribute: ThomasFormInput.Attribute? {
        guard
            let name = self.info.properties.attributeName,
            let value = self.info.properties.attributeValue
        else {
            return nil
        }

        return ThomasFormInput.Attribute(
            attributeName: name,
            attributeValue: value
        )
    }

    private func updateValue(_ isOn: Bool) {
        let data = ThomasFormInput(
            self.info.properties.identifier,
            value: .toggle(isOn),
            attribute: isOn ? self.attribute : nil,
            isValid: isOn || !(self.info.validation.isRequired ?? false)
        )

        self.formState.updateFormInput(data)
    }

    private func restoreFormState() {
        let formValue = self.formState.data.input(
            identifier: self.info.properties.identifier
        )?.value

        guard case let .toggle(value) = formValue else {
            return
        }

        self.isOn = value
    }

}
