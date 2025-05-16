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
        return Binding<Bool>(
            get: {
                self.radioInputState.selectedItem == self.info.properties.reportingValue
            },
            set: {
                if $0 {
                    self.radioInputState.updateSelectedItem(
                        reportingValue: self.info.properties.reportingValue,
                        attributeValue: self.info.properties.attributeValue
                    )
                }
            }
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
        .accessible(self.info.accessible)
        .formElement()
    }
}
