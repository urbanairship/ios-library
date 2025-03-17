/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @Environment(\.pageIdentifier) var pageID
    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasState: ThomasState
    @StateObject var radioInputState: RadioInputState = RadioInputState()
    @State private var isValid: Bool?

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
            case .radio(let value) = self.formState.field(
                identifier: self.info.properties.identifier
            )?.input,
            let value
        else {
            updateFormState(self.radioInputState.selectedItem)
            return
        }

        self.radioInputState.selectedItem = value
    }

    @MainActor
    private func updateValidationState(
        _ status: ThomasFormState.Status
    ) {
        switch (status) {
        case .valid:
            guard self.isValid == true else {
                self.info.validation.onValid?.stateActions.map(handleStateActions)
                self.isValid = true
                return
            }
        case .error, .invalid:
            guard let fieldStatus = self.formState.lastFieldStatus(
                identifier: self.info.properties.identifier
            ) else {
                return
            }

            if fieldStatus.isValid {
                guard self.isValid == true else {
                    self.info.validation.onValid?.stateActions.map(handleStateActions)
                    self.isValid = true
                    return
                }
            } else if fieldStatus == .invalid {
                guard
                    self.isValid == false
                else {
                    self.info.validation.onError?.stateActions.map(handleStateActions)
                    self.isValid = false
                    return
                }
            }
        case .validating, .pendingValidation, .submitted: return
        }
    }

    private func handleStateActions(_ stateActions: [ThomasStateAction]) {
        thomasState.processStateActions(
            stateActions,
            formFieldValue: .radio(self.radioInputState.selectedItem)
        )
    }

    private func checkValid(value: String?) -> Bool {
        return value != nil || info.validation.isRequired != true
    }

    private var attributes: [ThomasFormField.Attribute]? {
        guard
            let name = info.properties.attributeName,
            let value = self.radioInputState.attributeValue
        else {
            return nil
        }

        return  [
            ThomasFormField.Attribute(
                attributeName: name,
                attributeValue: value
            )
        ]
    }

    private func updateFormState(_ value: String?) {
        let field: ThomasFormField = if checkValid(value: value) {
            ThomasFormField.validField(
                identifier: self.info.properties.identifier,
                input: .radio(value),
                result: .init(
                    value: .radio(value),
                    attributes: self.attributes
                )
           )
        } else {
            ThomasFormField.invalidField(
                identifier: self.info.properties.identifier,
                input: .radio(value)
            )
        }
        
        self.formDataCollector.updateField(field, pageID: pageID)
    }

}
