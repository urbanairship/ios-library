/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct CheckboxToggleLayout: View {
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var checkboxState: CheckboxState
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .checkboxToggleLayout,
            thomasState: thomasState
        )
    }

    private let info: ThomasViewInfo.CheckboxToggleLayout
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.CheckboxToggleLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var isOnBinding: Binding<Bool> {
        self.checkboxState.makeBinding(
            identifier: info.properties.identifier,
            reportingValue: info.properties.reportingValue
        )
    }

    private var isEnabled: Bool {
        let isSelected = self.checkboxState.isSelected(
            identifier: info.properties.identifier
        )

        return isSelected || !self.checkboxState.isMaxSelectionReached
    }

    var body: some View {
        ToggleLayout(
            isOn: self.isOnBinding,
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
            associatedLabel: associatedLabel,
            hideIfDescriptionIsMissing: false
        )
        .formElement()
    }
}
