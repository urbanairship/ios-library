/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct AirshipSwitchToggleStyle: ToggleStyle {
    let info: ThomasToggleStyleInfo.Switch
    
    func makeBody(configuration: Self.Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {}
            .buttonStyle(
                AirshipSwitchButtonStyle(info: info, isOn: configuration.$isOn)
            )
    }
    
    struct AirshipSwitchButtonStyle: ButtonStyle {
        let info: ThomasToggleStyleInfo.Switch
        var isOn: Binding<Bool>
        
        func makeBody(configuration: Self.Configuration) -> some View {
            ButtonView(configuration: configuration, info: info, isOn: isOn)
        }
        
        struct ButtonView: View {
            let configuration: ButtonStyle.Configuration
            let info: ThomasToggleStyleInfo.Switch
            var isOn: Binding<Bool>
            
            @Environment(\.isFocused) var isFocused
            @Environment(\.isEnabled) var isEnabled
            @Environment(\.colorScheme) var colorScheme

            static let trackWidth = 50.0
            static let thumbDiameter = 30.0
            static let thumbPadding = 1.5
            static let pressedThumbStretch = 4.0
            
            static let offSet = (trackWidth - thumbDiameter) / 2
            static let pressedOffset = offSet - (pressedThumbStretch / 2)
            
            @ViewBuilder
            func createOverlay(isPressed: Bool) -> some View {
                if isPressed {
                    Capsule()
                        .fill(Color.white)
                        .shadow(radius: 1, x: 0, y: 1)
                        .frame(width: Self.thumbDiameter + Self.pressedThumbStretch)
                        .padding(Self.thumbPadding)
                        .offset(x: isOn.wrappedValue ? Self.pressedOffset : -Self.pressedOffset)
                } else {
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 1, x: 0, y: 1)
                        .padding(Self.thumbPadding)
                        .offset(x: isOn.wrappedValue ? Self.offSet : -Self.offSet)
                }
            }
            
            var body: some View {
                let fill = self.isOn.wrappedValue ? self.info.colors.on.toColor(colorScheme) : self.info.colors.off.toColor(colorScheme)
   
                Capsule()
                    .fill(fill)
                    .frame(width: Self.trackWidth, height: Self.thumbDiameter)
                    .overlay(createOverlay(isPressed: configuration.isPressed))
                    .animation(Animation.easeInOut(duration: 0.05), value: self.isOn.wrappedValue)
                    .colorMultiply(isEnabled ? Color.white : ThomasConstants.disabledColor)
                    .saturation(isEnabled ? 1.0 : 0.5)
#if os(tvOS)
                    .hoverEffect(.highlight, isEnabled: isFocused)
#endif
                    .addSelectedTrait(self.isOn.wrappedValue)   
            }
        }
    }
}
