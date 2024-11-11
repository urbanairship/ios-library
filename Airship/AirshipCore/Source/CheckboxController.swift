import Combine
import Foundation
import SwiftUI


struct CheckboxController: View {
    let info: ThomasViewInfo.CheckboxController
    let constraints: ViewConstraints

    @EnvironmentObject var formState: FormState
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
            .airshipOnChangeOf(self.checkboxState.selectedItems) { [info, weak formState] incoming in
                let selected = Array(incoming)
                let isFilled =
                selected.count >= (info.properties.minSelection ?? 0)
                    && selected.count
                <= (info.properties.maxSelection ?? Int.max)

                let isValid =
                    isFilled
                    || (selected.count == 0
                        && info.validation.isRequired == false)

                let data = FormInputData(
                    self.info.properties.identifier,
                    value: .multipleCheckbox(selected),
                    isValid: isValid
                )

                formState?.updateFormInput(data)
            }
            .onAppear {
                restoreFormState()
            }
    }

    private func restoreFormState() {
        let formValue = self.formState.data.formValue(
            identifier: self.info.properties.identifier
        )

        guard case let .multipleCheckbox(value) = formValue,
            let value = value
        else {
            return
        }

        self.checkboxState.selectedItems = Set<String>(value)
    }
}
