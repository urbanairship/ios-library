/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextInput : View {
    let model: TextInputModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var formState: FormState
    @State private var input: String = ""
    
    @ViewBuilder
    private func createTextEditor() -> some View {
        let binding = Binding<String>(
            get: { self.input },
            set: { self.input = $0; self.updateValue($0) }
        )
        
        AirshipTextInput(model: self.model, text: binding)
    }

    var body: some View {
        createTextEditor()
            .constraints(constraints, alignment: .topLeading)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .viewAccessibility(label: self.model.contentDescription)
            .formInput()
            .onAppear {
                updateValue(input)
            }
    }
    
    private func updateValue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let isValid = !trimmed.isEmpty || !(self.model.isRequired ?? false)
        let data = FormInputData(self.model.identifier,
                                 value: .text(trimmed.isEmpty ? nil : trimmed),
                                 isValid: isValid)
        self.formState.updateFormInput(data)
    }
}
