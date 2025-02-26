/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @EnvironmentObject var parentFormState: ThomasFormState
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
            case let .radio(value) = self.parentFormState.data.input(
                identifier: self.info.properties.identifier
            )?.value,
            let value = value
        else {
            updateFormState(self.radioInputState.selectedItem)
            return
        }

        self.radioInputState.selectedItem = value
    }

    
    private var attribute: ThomasFormInput.Attribute? {
        guard
            let name = info.properties.attributeName,
            let value = self.radioInputState.attributeValue
        else {
            return nil
        }
        
        return ThomasFormInput.Attribute(
            attributeName: name,
            attributeValue: value
        )
    }

    private func updateFormState(_ value: String?) {
        let data = ThomasFormInput(
            self.info.properties.identifier,
            value: .radio(value),
            attribute: self.attribute,
            isValid: value != nil || self.info.validation.isRequired != true
        )
        self.parentFormState.updateFormInput(data)
    }

}
