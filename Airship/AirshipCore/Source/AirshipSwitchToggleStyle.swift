/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipSwitchToggleStyle: ToggleStyle {
    let model: SwitchToggleStyleModel
    let colorScheme: ColorScheme

    @Environment (\.isEnabled) var isEnabled

    func makeBody(configuration: Self.Configuration) -> some View {
        let colors = self.model.colors
        let fill = configuration.isOn ? colors.on.toColor(colorScheme) : colors.off.toColor(colorScheme)
        Button(action: { configuration.isOn.toggle() } ) {}
            .buttonStyle(AirshipSwitchButtonStyle(fillColor: fill,
                                                  isOn: configuration.isOn))
            .applyIf(!isEnabled) {
                $0.saturation(0.5)
            }
    }
    
    struct AirshipSwitchButtonStyle: ButtonStyle {
        let fillColor: Color
        let isOn: Bool
        
        static let trackWidth = 50.0
        static let thumbDiameter = 30.0
        static let thumbPadding = 1.5
        static let pressedThumbStretch = 4.0
        
        static let offSet = (trackWidth - thumbDiameter)/2
        static let pressedOffset = offSet - (pressedThumbStretch/2)

        @ViewBuilder
        func createOverlay(isPressed: Bool) -> some View  {
            if (isPressed) {                            
                RoundedRectangle(cornerRadius: AirshipSwitchButtonStyle.thumbDiameter, style: .continuous)
                                .fill(Color.white)
                                .shadow(radius: 1, x: 0, y: 1)
                                .frame(width: AirshipSwitchButtonStyle.thumbDiameter + AirshipSwitchButtonStyle.pressedThumbStretch)
                                .padding(AirshipSwitchButtonStyle.thumbPadding)
                                .offset(x: isOn ? AirshipSwitchButtonStyle.pressedOffset  : -AirshipSwitchButtonStyle.pressedOffset)
            } else {
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 1, x: 0, y: 1)
                    .padding(AirshipSwitchButtonStyle.thumbPadding)
                    .offset(x: isOn ? AirshipSwitchButtonStyle.offSet : -AirshipSwitchButtonStyle.offSet)
            }
        }
        
        func makeBody(configuration: Self.Configuration) -> some View {
            RoundedRectangle(cornerRadius: AirshipSwitchButtonStyle.thumbDiameter,
                             style: .circular)
                .fill(fillColor)
                .frame(width: AirshipSwitchButtonStyle.trackWidth, height: AirshipSwitchButtonStyle.thumbDiameter)
                .overlay(createOverlay(isPressed: configuration.isPressed))
                .animation(Animation.easeInOut(duration: 0.05))
        }
    }
}
