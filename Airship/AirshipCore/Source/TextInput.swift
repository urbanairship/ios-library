import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextInput : View {
    let model: TextInputModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var formState: FormState
    @State private var input: String = ""
    
    var body: some View {
        let binding = Binding<String>(
            get: { self.input },
            set: { self.input = $0; self.updateValue($0) }
        )

        TextField("", text: binding)
            .constraints(constraints)
            .onAppear {
                updateValue(input)
            }
    }
    
    private func updateValue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let isValid = !trimmed.isEmpty || !(self.model.isRequired ?? false)
        let data = FormInputData(isValid: isValid,
                                 value: .text(trimmed.isEmpty ? nil : trimmed))
        self.formState.updateFormInput(self.model.identifier, data: data)
    }
}
