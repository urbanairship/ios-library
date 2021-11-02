/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipCheckboxToggleStyle: ToggleStyle {
    let backgroundColor: HexColor?
    let border: Border?
    let viewConstraints: ViewConstraints
    let model: CheckboxToggleStyleModel
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        let checkedColors = self.model.checkedColors
        
        let backgroundColor = isOn ? (checkedColors.background ??  self.backgroundColor) : self.backgroundColor
        let checkMarkColor = checkedColors.checkMark
        
        var border: Border? = self.border
        border?.strokeColor = isOn ? (checkedColors.border ??  self.border?.strokeColor) : self.border?.strokeColor
        
        return Button(action: { configuration.isOn.toggle() } ) {
            ZStack {
                Shapes.rectangle(color: backgroundColor, border: border)
                GeometryReader { reader in
                    if (configuration.isOn) {
                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(checkMarkColor.toColor())
                            .padding(self.border?.strokeWidth ?? 0)
                            .frame(width: reader.size.width * 0.55, height: reader.size.height * 0.55)
                            .position(x: reader.size.width / 2, y: reader.size.height / 2)
                    }
                }
            }
        }.frame(width: viewConstraints.width ?? 32,
                height: viewConstraints.height ?? 32,
                alignment: .center)
            .animation(Animation.easeInOut(duration: 0.05))
    }
}
