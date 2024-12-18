/* Copyright Airship and Contributors */

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
            .airshipOnChangeOf(self.radioInputState.selectedItem) { incoming in
                updateFormState(incoming)
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
            updateFormState(self.radioInputState.selectedItem)
            return
        }

        self.radioInputState.selectedItem = value
    }

    private func updateFormState(_ value: String?) {
        let data = FormInputData(
            self.info.properties.identifier,
            value: .radio(value),
            attributeName: self.info.properties.attributeName,
            attributeValue: self.radioInputState.attributeValue,
            isValid: value != nil || self.info.validation.isRequired != true
        )
        self.parentFormState.updateFormInput(data)
    }

}
