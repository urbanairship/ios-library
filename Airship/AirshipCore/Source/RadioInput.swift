/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct RadioInput : View {
    let model: RadioInputModel
    let constraints: ViewConstraints
    @EnvironmentObject var radioInputState: RadioInputState
    
        
    @ViewBuilder
    var body: some View {
        let isOn = Binding<Bool>(
            get: { self.radioInputState.selectedItem == self.model.value },
            set: {
                if ($0) {
                    self.radioInputState.selectedItem = self.model.value
                }
            }
        )
        
        Toggle(isOn: isOn.animation()) {}
        .toggleStyle(AirshipRadioToggleStyle(backgroundColor: self.model.backgroundColor, foregroundColor: self.model.foregroundColor, border: self.model.border, viewConstraints: self.constraints))
        .constraints(constraints)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct AirshipRadioToggleStyle: ToggleStyle {
    let backgroundColor: HexColor?
    let foregroundColor: HexColor
    let border: Border?
    let viewConstraints: ViewConstraints
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        let width = self.viewConstraints.width ?? self.viewConstraints.height ?? 32
        let height = self.viewConstraints.height ?? self.viewConstraints.height ?? 32
        
        let outerBorder: Border = self.border ?? Border(radius: max(width, height),
                                                   strokeWidth: 2,
                                                   strokeColor: self.foregroundColor)
        
        var innerBorder: Border = outerBorder
        innerBorder.strokeColor = nil
        
    
        return Button(action: { configuration.isOn.toggle() } ) {
            ZStack {
                Shapes.rectangle(color: self.backgroundColor, border: outerBorder)
                
                if (isOn) {
                    Shapes.rectangle(color: self.foregroundColor, border: innerBorder)
                        .padding([.leading, .trailing], width * 0.2)
                        .padding([.top, .bottom], height * 0.2)
                }
            }
        }.frame(width: width,
                height: height,
                alignment: .center)
            .animation(Animation.easeInOut(duration: 0.05))
    }
}

