/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Score : View {
    
    let model: ScoreModel
    let constraints: ViewConstraints
    
    @State var score: Int?
    @EnvironmentObject var formState: FormState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createScore() -> some View {
        switch(self.model.style) {
        case .numberRange(let style):
            HStack(spacing: style.spacing ?? 0) {
                ForEach((style.start...style.end), id: \.self) { index in
                    let isOn = Binding<Bool>(
                        get: { self.score == index },
                        set: { if ($0) { updateScore(index) } }
                    )
                    
                    Toggle(isOn: isOn.animation()) {}
                    .toggleStyle(AirshipNumberRangeToggleStyle(style: style,
                                                               viewConstraints: constraints,
                                                               value: index,
                                                               colorScheme: colorScheme))
                }
            }
        }
    }
 
    var body: some View {
        createScore()
            .constraints(modifiedConstraints())
            .border(self.model.border)
            .background(self.model.backgroundColor)
            .viewAccessibility(label: self.model.contentDescription)
            .onAppear {
                self.updateScore(self.score)
            }
            .formInput()
    }
    
    private func modifiedConstraints() -> ViewConstraints {
        var constraints = self.constraints
        if (self.constraints.width == nil && self.constraints.height == nil) {
            constraints.height = 32
        }
        
        return constraints
    }
    
    private func updateScore(_ value: Int?) {
        self.score = value
        let isValid = value != nil || self.model.isRequired != true
        let data = FormInputData(isValid: isValid, value: .score(value))
        self.formState.updateFormInput(self.model.identifier, data: data)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct AirshipNumberRangeToggleStyle: ToggleStyle {
    
    let style: ScoreNumberRangeStyle
    let viewConstraints: ViewConstraints
    let value: Int
    let colorScheme: ColorScheme
   
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        return Button(action: { configuration.isOn.toggle() } ) {
            ZStack {
                // Drwaing both with 1 hidden in case the content size changes between the two
                // it will prevent the parent from resizing on toggle
                Group {
                    if let shapes = style.bindings.selected.shapes {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(model: shapes[index], colorScheme: colorScheme)
                        }
                        .opacity(isOn ? 1 : 0)
                    }
                    Text(String(self.value))
                        .textAppearance(style.bindings.selected.textAppearance)
                       
                }.opacity(isOn ? 1 : 0)
                
                Group {
                    if let shapes = style.bindings.unselected.shapes {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(model: shapes[index], colorScheme: colorScheme)
                        }
                    }
                    Text(String(self.value))
                        .textAppearance(style.bindings.unselected.textAppearance)
                }
                .opacity(isOn ? 0 : 1)
               
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(Animation.easeInOut(duration: 0.05))
    }

}
