/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasState: ThomasState
    @StateObject var radioInputState: RadioInputState = RadioInputState()
    @State private var isValid: Bool?
    @State var formInput: ThomasFormInput?

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
            .formElement()
            .environmentObject(radioInputState)
            .airshipOnChangeOf(self.formState.status) { status in
                guard self.formState.validationMode == .onDemand else { return }
                updateValidationState(status)
            }
            .airshipOnChangeOf(self.radioInputState.selectedItem) { incoming in
                updateFormState(incoming)

                guard self.formState.validationMode == .onDemand else { return }
                if self.isValid != nil {
                    self.info.validation.onEdit?.stateActions.map(handleStateActions)
                    self.isValid = nil
                }
                updateValidationState(self.formState.status)
            }
            .onAppear {
                restoreFormState()
            }
    }

    private func restoreFormState() {
        guard
            case let .radio(value) = self.formState.data.input(
                identifier: self.info.properties.identifier
            )?.value,
            let value = value
        else {
            updateFormState(self.radioInputState.selectedItem)
            return
        }

        self.radioInputState.selectedItem = value
    }

    @MainActor
    private func updateValidationState(
        _ status: ThomasFormStatus
    ) {
        switch (status) {
        case .valid:
            guard self.isValid == true else {
                self.info.validation.onValid?.stateActions.map(handleStateActions)
                self.isValid = true
                return
            }
        case .error(let result), .invalid(let result):
            let id = self.info.properties.identifier
            if result.status[id] == .invalid {
                guard
                    self.isValid == false
                else {
                    self.info.validation.onError?.stateActions.map(handleStateActions)
                    self.isValid = false
                    return
                }
            } else if result.status[id] == .valid {
                guard self.isValid == true else {
                    self.info.validation.onValid?.stateActions.map(handleStateActions)
                    self.isValid = true
                    return
                }
            }
        case .validating, .pendingValidation, .submitted: return
        }
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
        thomasState.processStateActions(
            stateActions,
            formInput: self.formState.data.input(identifier: self.info.properties.identifier)
        )
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
            validator: .just(value != nil || self.info.validation.isRequired != true)
        )
        self.formState.updateFormInput(data)
    }

}
