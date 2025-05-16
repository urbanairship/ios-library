/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct CheckboxToggleLayout: View {
    @EnvironmentObject var formState: ThomasFormState
    @EnvironmentObject var checkboxState: CheckboxState

    let info: ThomasViewInfo.CheckboxToggleLayout
    let constraints: ViewConstraints

    private var isOnBinding: Binding<Bool> {
        return Binding<Bool>(
            get: {
                self.checkboxState.selectedItems.contains(
                    self.info.properties.reportingValue
                )
            },
            set: {
                if $0 {
                    self.checkboxState.selectedItems.insert(
                        self.info.properties.reportingValue
                    )
                } else {
                    self.checkboxState.selectedItems.remove(
                        self.info.properties.reportingValue
                    )
                }
            }
        )
    }

    private var isEnabled: Bool {
        let isSelected = self.checkboxState.selectedItems.contains(
            self.info.properties.reportingValue
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
        .accessible(self.info.accessible)
        .formElement()
    }
}
