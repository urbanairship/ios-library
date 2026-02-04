/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct BasicToggleLayout: View {

    @Environment(\.pageIdentifier) private var pageID
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var formDataCollector: ThomasFormDataCollector
    @State private var isOn: Bool = false

    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .basicToggleLayout,
            thomasState: thomasState
        )
    }

    private let info: ThomasViewInfo.BasicToggleLayout
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.BasicToggleLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

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
        .accessible(
            self.info.accessible,
            associatedLabel: self.associatedLabel,
            hideIfDescriptionIsMissing: false
        )
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
