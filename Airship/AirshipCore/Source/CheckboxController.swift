/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct CheckboxController: View {
    let info: ThomasViewInfo.CheckboxController
    let constraints: ViewConstraints

    @Environment(\.pageIdentifier) var pageID
    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasState: ThomasState
    @StateObject var checkboxState: CheckboxState
    @State private var isValid: Bool?

    init(info: ThomasViewInfo.CheckboxController, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
        self._checkboxState = StateObject(
            wrappedValue: CheckboxState(
                minSelection: info.properties.minSelection,
                maxSelection: info.properties.maxSelection
            )
        )
    }

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
            .formElement()
            .environmentObject(checkboxState)
            .airshipOnChangeOf(self.formState.status) { status in
                guard self.formState.validationMode == .onDemand else { return }
                updateValidationState(status)
            }
            .airshipOnChangeOf(self.checkboxState.selectedItems) { incoming in
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
            formFieldValue: .multipleCheckbox(self.checkboxState.selectedItems)
        )
    }

    private func restoreFormState() {
        guard
            case .multipleCheckbox(let value) = self.formState.field(
                identifier: self.info.properties.identifier
            )?.input
        else {
            updateFormState(self.checkboxState.selectedItems)
            return
        }

        self.checkboxState.selectedItems = Set(value)
    }

    private func checkValid(_ value: Set<String>) -> Bool {
        let min = info.properties.minSelection ?? 0
        let max = info.properties.maxSelection ?? Int.max

        guard value.count >= min, value.count <= max else {
            return false
        }

        guard !value.isEmpty else {
            return info.validation.isRequired != true
        }

        return true
    }

    private func updateFormState(_ value: Set<String>) {
        let formValue: ThomasFormField.Value = .multipleCheckbox(value)
        let field: ThomasFormField = if checkValid(value) {
            ThomasFormField.validField(
                identifier: self.info.properties.identifier,
                input: formValue,
                result: .init(
                    value: formValue
                )
           )
        } else {
            ThomasFormField.invalidField(
                identifier: self.info.properties.identifier,
                input: formValue
            )
        }

        self.formDataCollector.updateField(field, pageID: pageID)
    }
}
