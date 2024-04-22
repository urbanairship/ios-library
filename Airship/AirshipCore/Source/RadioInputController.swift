import Combine
import Foundation
import SwiftUI


struct RadioInputController: View {
    let model: RadioInputControllerModel
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: FormState
    @StateObject var radioInputState: RadioInputState = RadioInputState()

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .accessible(self.model)
            .formElement()
            .environmentObject(radioInputState)
            .airshipOnChangeOf(self.radioInputState.selectedItem) { [weak parentFormState, model, weak radioInputState] incoming in
                let data = FormInputData(
                    model.identifier,
                    value: .radio(incoming),
                    attributeName: model.attributeName,
                    attributeValue: radioInputState?.attributeValue,
                    isValid: incoming != nil || model.isRequired != true
                )
                parentFormState?.updateFormInput(data)
            }
            .onAppear {
                restoreFormState()
            }
    }

    private func restoreFormState() {
        guard
            case let .radio(value) = self.parentFormState.data.formValue(
                identifier: self.model.identifier
            ),
            let value = value
        else {
            return
        }

        self.radioInputState.selectedItem = value
    }
}
