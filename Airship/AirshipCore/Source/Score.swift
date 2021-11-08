/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Score : View {
    
    let model: ScoreModel
    let constraints: ViewConstraints
    
    @State var score: Int?
    @EnvironmentObject var formState: FormState
            
    @ViewBuilder
    private func createScore() -> some View {
        switch(self.model.style) {
        case .nps(let style):
            HStack(spacing: style.spacing ?? 0) {
                ForEach((0..<11), id: \.self) { index in
                    let isOn = Binding<Bool>(
                        get: { self.score == index },
                        set: { if ($0) { updateScore(index) } }
                    )
                    
                    Toggle(isOn: isOn.animation()) {}
                    .toggleStyle(AirshipScoreToggleStyle(style: style, viewConstraints: constraints, value: index))
                    .scaledToFit()
                }
            }
        }
    }
 
    var body: some View {
        createScore()
            .constraints(self.constraints)
            .border(self.model.border)
            .background(self.model.backgroundColor)
            .onAppear {
                self.updateScore(self.score)
            }
    }
    
    private func updateScore(_ value: Int?) {
        self.score = value
        let isValid = value != nil || self.model.isRequired != true
        let data = FormInputData(isValid: isValid, value: .score(value))
        self.formState.updateFormInput(self.model.identifier, data: data)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private struct AirshipScoreToggleStyle: ToggleStyle {
    
    let style: ScoreNPSStyleModel
    let viewConstraints: ViewConstraints
    let value: Int
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        
        let totalWidth = (self.viewConstraints.width ?? 320)
        let totalSpacing = (10 * (self.style.spacing ?? 0))
        let width = (totalWidth - totalSpacing)/11
        let size = min(width, self.viewConstraints.height ?? width)
        
        return Button(action: { configuration.isOn.toggle() } ) {
            Text(String(self.value))
                .textStyles(self.style.textStyles)
                .airshipFont(self.style.fontSize, self.style.fontFamilies)
                .foreground(isOn ? self.style.selectedColors.number : self.style.deselectedColors.number)
                .frame(idealWidth: size, maxWidth: size, idealHeight: size, maxHeight: size)
        }
        .animation(Animation.easeInOut(duration: 0.05))
        .background(isOn ? self.style.selectedColors.fill : self.style.deselectedColors.fill)
        .border(style.outlineBorder)
    }
}

