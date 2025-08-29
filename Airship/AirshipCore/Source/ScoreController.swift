/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct ScoreController: View {
    let info: ThomasViewInfo.ScoreController
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
        let info: ThomasViewInfo.ScoreController
        let constraints: ViewConstraints

        @Environment(\.pageIdentifier) var pageID
        @EnvironmentObject var formDataCollector: ThomasFormDataCollector
        @EnvironmentObject var formState: ThomasFormState
        @EnvironmentObject var thomasState: ThomasState
        @ObservedObject var scoreState: ScoreState
        @EnvironmentObject var validatableHelper: ValidatableHelper
        @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver

        private var associatedLabel: String? {
            associatedLabelResolver?.labelFor(
                identifier: info.properties.identifier,
                viewType: .scoreController,
                thomasState: thomasState
            )
        }
        
        init(
            info: ThomasViewInfo.ScoreController,
            constraints: ViewConstraints,
            environment: ThomasEnvironment
        ) {
            self.info = info
            self.constraints = constraints

            // Use the environment to create or retrieve the state in case the view
            // stack changes and we lose our state.
            let scoreState = environment.retrieveState(identifier: info.properties.identifier) {
                ScoreState()
            }

            self._scoreState = ObservedObject(wrappedValue: scoreState)
        }


        var body: some View {
            ViewFactory.createView(self.info.properties.view, constraints: constraints)
                .constraints(constraints)
                .thomasCommon(self.info, formInputID: self.info.properties.identifier)
                .accessible(
                    self.info.accessible,
                    associatedLabel: associatedLabel,
                    hideIfDescriptionIsMissing: true
                )
                .formElement()
                .environmentObject(scoreState)
                .airshipOnChangeOf(self.scoreState.selected) { incoming in
                    updateFormState(selected: incoming)
                }
                .onAppear {
                    updateFormState(selected: self.scoreState.selected)
                    if self.formState.validationMode == .onDemand {
                        validatableHelper.subscribe(
                            forIdentifier: info.properties.identifier,
                            formState: formState,
                            initialValue: scoreState.selected,
                            valueUpdates: scoreState.$selected,
                            validatables: info.validation
                        ) { [weak thomasState, weak scoreState] actions in
                            guard let thomasState, let scoreState else { return }
                            thomasState.processStateActions(
                                actions,
                                formFieldValue: .score(scoreState.selected?.reportingValue)
                            )
                        }
                    }
                }
        }

        private func checkValid(value: AirshipJSON?) -> Bool {
            return value != nil || info.validation.isRequired != true
        }

        private func makeAttribute(
            selected: ScoreState.Selected?
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

        private func updateFormState(selected: ScoreState.Selected?) {
            let field: ThomasFormField = if checkValid(value: selected?.reportingValue) {
                ThomasFormField.validField(
                    identifier: self.info.properties.identifier,
                    input: .score(selected?.reportingValue),
                    result: .init(
                        value: .score(selected?.reportingValue),
                        attributes: makeAttribute(selected: selected)
                    )
                )
            } else {
                ThomasFormField.invalidField(
                    identifier: self.info.properties.identifier,
                    input: .score(selected?.reportingValue)
                )
            }

            self.formDataCollector.updateField(field, pageID: pageID)
        }
    }
}
