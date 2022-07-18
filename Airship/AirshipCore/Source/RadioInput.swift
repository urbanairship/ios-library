/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct RadioInput : View {
    let model: RadioInputModel
    let constraints: ViewConstraints
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var radioInputState: RadioInputState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createToggle() -> some View  {
        let isOn = Binding<Bool>(
            get: { self.radioInputState.selectedItem == self.model.value },
            set: {
                if ($0) {
                    self.radioInputState.selectedItem = self.model.value
                }
            }
        )
        
        let toggle = Toggle(isOn: isOn.animation()) {}
        
        switch (self.model.style) {
        case .checkboxStyle(let style):
            toggle.toggleStyle(AirshipCheckboxToggleStyle(viewConstraints: self.constraints,
                                                          model: style,
                                                          colorScheme: colorScheme))
        case .switchStyle(let style):
            toggle.toggleStyle(AirshipSwitchToggleStyle(model: style, colorScheme: colorScheme))
        }
    }
        
    
    @ViewBuilder
    var body: some View {
        createToggle()
            .constraints(constraints)
            .background(model.backgroundColor)
            .border(model.border)
            .common(self.model)
            .formElement()
            .onAppear {
                self.radioInputState.attributeValue = self.model.attributeValue
            }
    }
}

