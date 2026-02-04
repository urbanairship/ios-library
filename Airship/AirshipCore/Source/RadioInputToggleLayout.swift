/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct RadioInputToggleLayout: View {
    @EnvironmentObject private var formState: ThomasFormState
    @EnvironmentObject private var radioInputState: RadioInputState
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasAssociatedLabelResolver) private var associatedLabelResolver

    private var associatedLabel: String? {
        associatedLabelResolver?.labelFor(
            identifier: info.properties.identifier,
            viewType: .radioInputToggleLayout,
            thomasState: thomasState
        )
    }

    private let info: ThomasViewInfo.RadioInputToggleLayout
    private let constraints: ViewConstraints

    init(info: ThomasViewInfo.RadioInputToggleLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var isOnBinding: Binding<Bool> {
        return radioInputState.makeBinding(
            identifier: info.properties.identifier,
            reportingValue: info.properties.reportingValue,
            attributeValue: info.properties.attributeValue
        )
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
