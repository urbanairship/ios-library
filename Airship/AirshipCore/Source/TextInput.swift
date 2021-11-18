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
        
        if #available(iOS 14.0.0,  tvOS 14.0, *) {
            #if !os(tvOS)
            TextEditor(text: binding)
                .textAppearance(model.textAppearance)
            #else
            TextField(self.model.placeHolder ?? "", text: binding)
                .textAppearance(model.textAppearance)
            #endif
        } else {
            TextField(self.model.placeHolder ?? "", text: binding)
                .textAppearance(model.textAppearance)
        }
    }

    var body: some View {
        createTextEditor()
            .constraints(constraints, alignment: .topLeading)
            .background(self.model.backgroundColor)
            .border(self.model.border)
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
