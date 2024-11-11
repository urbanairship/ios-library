/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct RadioInput: View {
    let info: ThomasViewInfo.RadioInput
    let constraints: ViewConstraints
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var radioInputState: RadioInputState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createToggle() -> some View {
        let isOn = Binding<Bool>(
            get: { self.radioInputState.selectedItem == self.info.properties.reportingValue },
            set: {
                if $0 {
                    self.radioInputState.updateSelectedItem(self.info)
                }
            }
        )

        Toggle(isOn: isOn.animation()) {}
            .thomasToggleStyle(
                self.info.properties.style,
                colorScheme: colorScheme,
                constraints: self.constraints,
                disabled: !formState.isFormInputEnabled
            )
    }

    @ViewBuilder
    var body: some View {
        createToggle()
            .constraints(constraints)
            .thomasCommon(self.info)
            .formElement()
    }
}
