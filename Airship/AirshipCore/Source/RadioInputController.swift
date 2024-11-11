import Combine
import Foundation
import SwiftUI


struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: FormState
    @StateObject var radioInputState: RadioInputState = RadioInputState()

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
            .formElement()
            .environmentObject(radioInputState)
            .airshipOnChangeOf(self.radioInputState.selectedItem) { [weak parentFormState, weak radioInputState] incoming in
                let data = FormInputData(
                    self.info.properties.identifier,
                    value: .radio(incoming),
                    attributeName: self.info.properties.attributeName,
                    attributeValue: radioInputState?.attributeValue,
                    isValid: incoming != nil || self.info.validation.isRequired != true
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
                identifier: self.info.properties.identifier
            ),
            let value = value
        else {
            return
        }

        self.radioInputState.selectedItem = value
    }
}
