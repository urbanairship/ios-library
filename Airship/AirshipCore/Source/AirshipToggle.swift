/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct AirshipToggle: View {
    private let info: ThomasViewInfo.Toggle
    private let constraints: ViewConstraints

    @Environment(\.pageIdentifier) private var pageID
    @EnvironmentObject private var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    @State private var isOn: Bool = false

    init(info: ThomasViewInfo.Toggle, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .toggle,
            thomasState: thomasState
        )
    }


    var body: some View {
        createToggle()
            .constraints(self.constraints)
            .thomasCommon(self.info, formInputID: self.info.properties.identifier)
            .accessible(
                self.info.accessible,
                associatedLabel: associatedLabel,
                hideIfDescriptionIsMissing: false
            )
            .formElement()
            .onAppear {
                restoreFormState()
                updateValue(self.isOn)
            }
    }

    @ViewBuilder
    private func createToggle() -> some View {
        let binding = Binding<Bool>(
            get: { self.isOn },
            set: {
                self.isOn = $0
                self.updateValue($0)
            }
        )
        
        Toggle(isOn: binding.animation()) {}
            .thomasToggleStyle(
                self.info.properties.style,
                constraints: self.constraints
            )
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

    private func updateValue(_ isOn: Bool) {
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
            self.updateValue(self.isOn)
            return
        }

        self.isOn = value
    }
}
