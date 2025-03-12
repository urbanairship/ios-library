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
            formInput: self.formState.child(identifier: self.info.properties.identifier)
        )
    }

    private func restoreFormState() {
        let formValue = self.formState.child(
            identifier: self.info.properties.identifier
        )?.value

        guard case let .multipleCheckbox(value) = formValue,
            let value = value
        else {
            updateFormState(self.checkboxState.selectedItems)
            return
        }

        self.checkboxState.selectedItems = Set<String>(value)
    }

    private func updateFormState(_ value: Set<String>) {
        let selected = Array(value)
        let isFilled =
        selected.count >= (info.properties.minSelection ?? 0)
            && selected.count
        <= (info.properties.maxSelection ?? Int.max)

        let isValid = isFilled || (selected.count == 0 && info.validation.isRequired == false)

        let data = ThomasFormInput(
            self.info.properties.identifier,
            value: .multipleCheckbox(selected)
        )

        self.formDataCollector.updateFormInput(
            data,
            validator: .just(isValid),
            pageID: pageID
        )
    }
}
