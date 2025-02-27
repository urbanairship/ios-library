/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct CheckboxController: View {
    let info: ThomasViewInfo.CheckboxController
    let constraints: ViewConstraints

    @EnvironmentObject var formState: ThomasFormState
    @StateObject var checkboxState: CheckboxState

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
            .airshipOnChangeOf(self.checkboxState.selectedItems) { incoming in
                updateFormState(incoming)
            }
            .onAppear {
                restoreFormState()
            }
    }

    private func restoreFormState() {
        let formValue = self.formState.data.input(
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
            value: .multipleCheckbox(selected),
            validator: .just(isValid)
        )

        formState.updateFormInput(data)
    }
}
