/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @EnvironmentObject var environment: ThomasEnvironment

    var body: some View {
        Content(
            info: self.info,
            constraints: constraints,
            environment: environment
        )
        .id(info.properties.identifier)
    }

    @MainActor
    struct Content: View {
        let info: ThomasViewInfo.RadioInputController
        let constraints: ViewConstraints

        @Environment(\.pageIdentifier) var pageID
        @EnvironmentObject var formDataCollector: ThomasFormDataCollector
        @EnvironmentObject var formState: ThomasFormState
        @EnvironmentObject var thomasState: ThomasState
        @ObservedObject var radioInputState: RadioInputState
        @EnvironmentObject var validatableHelper: ValidatableHelper

        init(
            info: ThomasViewInfo.RadioInputController,
            constraints: ViewConstraints,
            environment: ThomasEnvironment
        ) {
            self.info = info
            self.constraints = constraints

            // Use the environment to create or retrieve the state in case the view
            // stack changes and we lose our state.
            let radioInputState = environment.retrieveState(identifier: info.properties.identifier) {
                RadioInputState()
            }

            self._radioInputState = ObservedObject(wrappedValue: radioInputState)
        }

        var body: some View {
            ViewFactory.createView(self.info.properties.view, constraints: constraints)
                .constraints(constraints)
                .thomasCommon(self.info, formInputID: self.info.properties.identifier)
                .accessible(self.info.accessible, hideIfDescriptionIsMissing: false)
                .formElement()
                .environmentObject(radioInputState)
                .airshipOnChangeOf(self.radioInputState.selected) { incoming in
                    updateFormState(selected: incoming)
                }
                .onAppear {
                    updateFormState(selected: self.radioInputState.selected)
                    if self.formState.validationMode == .onDemand {
                        validatableHelper.subscribe(
                            forIdentifier: info.properties.identifier,
                            formState: formState,
                            initialValue: radioInputState.selected,
                            valueUpdates: radioInputState.$selected,
                            validatables: info.validation
                        ) { [weak thomasState, weak radioInputState] actions in
                            guard let thomasState, let radioInputState else { return }
                            thomasState.processStateActions(
                                actions,
                                formFieldValue: .radio(
                                    radioInputState.selected?.reportingValue
                                )
                            )
                        }
                    }
                }
        }

        private func checkValid(value: AirshipJSON?) -> Bool {
            return value != nil || info.validation.isRequired != true
        }

        private func makeAttribute(
            selected: RadioInputState.Selected?
        ) -> [ThomasFormField.Attribute]? {
            guard
                let name = info.properties.attributeName,
                let value = selected?.attributeValue
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

        private func updateFormState(selected: RadioInputState.Selected?) {
            let field: ThomasFormField = if checkValid(value: selected?.reportingValue) {
                ThomasFormField.validField(
                    identifier: self.info.properties.identifier,
                    input: .radio(selected?.reportingValue),
                    result: .init(
                        value: .radio(selected?.reportingValue),
                        attributes: makeAttribute(selected: selected)
                    )
                )
            } else {
                ThomasFormField.invalidField(
                    identifier: self.info.properties.identifier,
                    input: .radio(selected?.reportingValue)
                )
            }

            self.formDataCollector.updateField(field, pageID: pageID)
        }

    }
}
