import Combine
import Foundation
import SwiftUI


struct CheckboxController: View {
    let model: CheckboxControllerModel
    let constraints: ViewConstraints

    @EnvironmentObject var formState: FormState
    @StateObject var checkboxState: CheckboxState

    init(model: CheckboxControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self._checkboxState = StateObject(
            wrappedValue: CheckboxState(
                minSelection: model.minSelection,
                maxSelection: model.maxSelection
            )
        )
    }

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .accessible(self.model)
            .formElement()
            .environmentObject(checkboxState)
            .airshipOnChangeOf(self.checkboxState.selectedItems) { [model, weak formState] incoming in
                let selected = Array(incoming)
                let isFilled =
                    selected.count >= (model.minSelection ?? 0)
                    && selected.count
                        <= (model.maxSelection ?? Int.max)

                let isValid =
                    isFilled
                    || (selected.count == 0
                        && model.isRequired == false)

                let data = FormInputData(
                    model.identifier,
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
            identifier: self.model.identifier
        )

        guard case let .multipleCheckbox(value) = formValue,
            let value = value
        else {
            return
        }

        self.checkboxState.selectedItems = Set<String>(value)
    }
}
