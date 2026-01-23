/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct CheckboxController: View {
    let info: ThomasViewInfo.CheckboxController
    let constraints: ViewConstraints

    @EnvironmentObject var environment: ThomasEnvironment

    var body: some View {
        Content(
            info: self.info,
            constraints: constraints,
            environment: environment
        )
        .id(info.properties.identifier)
        .accessibilityElement(children: .contain)
    }

    @MainActor
    struct Content: View {
        let info: ThomasViewInfo.CheckboxController
        let constraints: ViewConstraints

        @Environment(\.pageIdentifier) var pageID
        @EnvironmentObject var formDataCollector: ThomasFormDataCollector
        @EnvironmentObject var formState: ThomasFormState
        @EnvironmentObject var thomasState: ThomasState
        @ObservedObject var checkboxState: CheckboxState
        @EnvironmentObject var validatableHelper: ValidatableHelper
        @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

        private var associatedLabel: String? {
            associatedLabelResolver?.labelFor(
                identifier: info.properties.identifier,
                viewType: .checkboxController,
                thomasState: thomasState
            )
        }

        init(
            info: ThomasViewInfo.CheckboxController,
            constraints: ViewConstraints,
            environment: ThomasEnvironment
        ) {
            self.info = info
            self.constraints = constraints

            // Use the environment to create or retrieve the state in case the view
            // stack changes and we lose our state.
            let checkboxState = environment.retrieveState(identifier: info.properties.identifier) {
                CheckboxState(
                    minSelection: info.properties.minSelection,
                    maxSelection: info.properties.maxSelection
                )
            }

            self._checkboxState = ObservedObject(wrappedValue: checkboxState)
        }

        var body: some View {
            ViewFactory.createView(self.info.properties.view, constraints: constraints)
                .constraints(constraints)
                .thomasCommon(self.info, formInputID: self.info.properties.identifier)
                .accessible(
                    self.info.accessible,
                    associatedLabel: associatedLabel,
                    hideIfDescriptionIsMissing: false
                )
                .formElement()
                .environmentObject(checkboxState)
                .airshipOnChangeOf(self.checkboxState.selected) { incoming in
                    updateFormState(selected: incoming)
                }
                .onAppear {
                    updateFormState(selected: self.checkboxState.selected)
                    if self.formState.validationMode == .onDemand {
                        validatableHelper.subscribe(
                            forIdentifier: info.properties.identifier,
                            formState: formState,
                            initialValue: checkboxState.selected,
                            valueUpdates: checkboxState.$selected,
                            validatables: info.validation
                        ) { [weak thomasState, weak checkboxState] actions in
                            guard let thomasState, let checkboxState else { return }
                            thomasState.processStateActions(
                                actions,
                                formFieldValue: .multipleCheckbox(
                                    Set(checkboxState.selected.map { $0.reportingValue })
                                )
                            )
                        }
                    }
                }
        }

        private func checkValid(_ value: Set<AirshipJSON>) -> Bool {
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

        private func updateFormState(selected: Set<CheckboxState.Selected>) {
            let value: Set<AirshipJSON> = Set(selected.map { $0.reportingValue })
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
}
