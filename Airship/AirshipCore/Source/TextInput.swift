/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextInput : View {
    let model: TextInputModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var formState: FormState
    @State private var input: String = ""
    @State private var isEditing: Bool = false

    @ViewBuilder
    private func createTextEditor() -> some View {
        let binding = Binding<String>(
            get: { self.input },
            set: { self.input = $0; self.updateValue($0) }
        )
        
        #if !os(watchOS)
        AirshipTextInput(model: self.model, text: binding, isEditing:  $isEditing)
        #endif
    }

    var body: some View {
        ZStack {
            if let hint = self.model.placeHolder {
                Text(hint)
                    .textAppearance(placeHolderTextApperance())
                    .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0 ))
                    .constraints(constraints, alignment:.topLeading)
                    .opacity(input.isEmpty && !isEditing ? 1 : 0)
                    .animation(.linear(duration: 0.1))
            }
            createTextEditor()
        }
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

    private func placeHolderTextApperance() -> some BaseTextAppearance {
        guard let color = self.model.textAppearance.placeHolderColor else {
            return self.model.textAppearance
        }

        var appearance = self.model.textAppearance
        appearance.color = color
        return appearance
    }
}
