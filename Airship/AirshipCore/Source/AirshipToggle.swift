/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipToggle : View {
    let model: ToggleModel
    let constraints: ViewConstraints

    @EnvironmentObject var formState: FormState
    @State private var isOn: Bool = false
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
        createToggle()
            .constraints(self.constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .accessible(self.model)
            .formElement()
            .onAppear {
                restoreFormState()
                updateValue(self.isOn)
            }
    }
    
    @ViewBuilder
    private func createToggle() -> some View  {
        let binding = Binding<Bool>(
            get: { self.isOn },
            set: { self.isOn = $0; self.updateValue($0) }
        )
        
        let toggle = Toggle(isOn: binding.animation()) {}

        switch (self.model.style) {
        case .checkboxStyle(let style):
            toggle.toggleStyle(AirshipCheckboxToggleStyle(viewConstraints: self.constraints,
                                                          model: style,
                                                          colorScheme: colorScheme))
        case .switchStyle(let style):
            toggle.toggleStyle(AirshipSwitchToggleStyle(model: style, colorScheme: colorScheme))
        }
    }
    
    private func updateValue(_ isOn: Bool) {
        let isValid = isOn || !(self.model.isRequired ?? false)
        let data = FormInputData(self.model.identifier,
                                 value: .toggle(isOn),
                                 attributeName: self.model.attributeName,
                                 attributeValue: isOn ? self.model.attributeValue : nil,
                                 isValid: isValid)
                                 
        self.formState.updateFormInput(data)
    }

    private func restoreFormState() {
        let formValue = self.formState.data.formValue(identifier: self.model.identifier)

        guard case let .toggle(value) = formValue
        else {
            return
        }

        self.isOn = value
    }

}
