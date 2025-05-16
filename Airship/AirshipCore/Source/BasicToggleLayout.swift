/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct BasicToggleLayout: View {

    @Environment(\.pageIdentifier) var pageID
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @State var isOn: Bool = false

    let info: ThomasViewInfo.BasicToggleLayout
    let constraints: ViewConstraints

    var body: some View {
        ToggleLayout(
            isOn: $isOn,
            onToggleOn: self.info.properties.onToggleOn,
            onToggleOff: self.info.properties.onToggleOff
        ) {
            ViewFactory.createView(
                self.info.properties.view,
                constraints: constraints
            )
        }
        .constraints(self.constraints)
        .thomasCommon(self.info, formInputID: self.info.properties.identifier)
        .accessible(self.info.accessible)
        .formElement()
        .airshipOnChangeOf(self.isOn, initial: true) { value in
            updateFormState(value)
        }
        .onAppear {
            restoreFormState()
        }
    }

    private var attributes: [ThomasFormField.Attribute]? {
        guard
            let name = self.info.properties.attributeName,
            let value = self.info.properties.attributeValue
        else {
            return nil
        }

        return [
            ThomasFormField.Attribute(
                attributeName: name,
                attributeValue: value
            )
        ]
    }

    private func checkValid(_ isOn: Bool) -> Bool {
        return isOn || self.info.validation.isRequired != true
    }

    private func updateFormState(_ isOn: Bool) {
        let formValue: ThomasFormField.Value = .toggle(isOn)

        let field: ThomasFormField = if checkValid(isOn) {
            ThomasFormField.validField(
                identifier: self.info.properties.identifier,
                input: formValue,
                result: .init(
                    value: formValue,
                    attributes: self.attributes
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

    private func restoreFormState() {
        guard
            case .toggle(let value) = self.formState.field(
                identifier: self.info.properties.identifier
            )?.input
        else {
            self.updateFormState(self.isOn)
            return
        }

        self.isOn = value
    }
}
