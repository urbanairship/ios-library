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
        fileprivate let info: ThomasToggleStyleInfo.Switch
        fileprivate var isOn: Binding<Bool>
        
        func makeBody(configuration: Self.Configuration) -> some View {
            ButtonView(configuration: configuration, info: info, isOn: isOn)
        }
        
        struct ButtonView: View {
            fileprivate let configuration: ButtonStyle.Configuration
            fileprivate let info: ThomasToggleStyleInfo.Switch
            fileprivate var isOn: Binding<Bool>

            @Environment(\.isFocused) private var isFocused
            @Environment(\.isEnabled) private var isEnabled
            @Environment(\.colorScheme) private var colorScheme

            private static let trackWidth: Double = 50.0
            private static let thumbDiameter: Double = 30.0
            private static let thumbPadding: Double = 1.5
            private static let pressedThumbStretch: Double = 4.0

            private static let offSet: Double = (trackWidth - thumbDiameter) / 2
            private static let pressedOffset: Double = offSet - (pressedThumbStretch / 2)
            
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
            }
        }
    }
}
