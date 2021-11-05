/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipToggle : View {
    let model: ToggleModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var formState: FormState
    @State private var isOn: Bool = false
    
    var body: some View {
        HStack {
            createToggle().constraints(self.constraints)
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
            toggle.toggleStyle(AirshipCheckboxToggleStyle(backgroundColor: self.model.backgroundColor,
                                                          border: self.model.border,
                                                          viewConstraints: self.constraints,
                                                          model: style))
        case .switchStyle(let style):
            toggle.toggleStyle(AirshipSwitchToggleStyle(model: style))
        }
    }
    
    private func updateValue(_ isOn: Bool) {
        let isValid = isOn || !(self.model.isRequired ?? false)
        let data = FormInputData(isValid: isValid,
                                 value: .checkbox(isOn))
        self.formState.updateFormInput(self.model.identifier, data: data)
    }
}
