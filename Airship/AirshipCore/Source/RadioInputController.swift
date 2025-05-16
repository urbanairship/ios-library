/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct RadioInputController: View {
    let info: ThomasViewInfo.RadioInputController
    let constraints: ViewConstraints

    @Environment(\.pageIdentifier) var pageID
    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var thomasState: ThomasState
    @StateObject var radioInputState: RadioInputState = RadioInputState()
    @EnvironmentObject var validatableHelper: ValidatableHelper

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(self.info.accessible)
            .formElement()
            .environmentObject(radioInputState)
            .airshipOnChangeOf(self.radioInputState.selectedItem) { incoming in
                updateFormState(incoming)
            }
            .onAppear {
                restoreFormState()
                if self.formState.validationMode == .onDemand {
                    validatableHelper.subscribe(
                        forIdentifier: info.properties.identifier,
                        formState: formState,
                        initialValue: radioInputState.selectedItem,
                        valueUpdates: radioInputState.$selectedItem,
                        validatables: info.validation
                    ) { [weak thomasState, weak radioInputState] actions in
                        guard let thomasState, let radioInputState else { return }
                        thomasState.processStateActions(
                            actions,
                            formFieldValue: .radio(radioInputState.selectedItem)
                        )
                    }
                }
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

    private func checkValid(value: AirshipJSON?) -> Bool {
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

    private func updateFormState(_ value: AirshipJSON?) {
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
