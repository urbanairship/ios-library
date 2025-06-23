/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct RadioInputToggleLayout: View {
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var radioInputState: RadioInputState

    let info: ThomasViewInfo.RadioInputToggleLayout
    let constraints: ViewConstraints

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
        .accessible(self.info.accessible, hideIfDescriptionIsMissing: false)
        .formElement()
    }
}
