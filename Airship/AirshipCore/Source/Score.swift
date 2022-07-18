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
    private func createScore(_ constraints: ViewConstraints) -> some View {
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
        let constraints = modifiedConstraints()
        createScore(constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model, formInputID: self.model.identifier)
            .accessible(self.model)
            .formElement()
            .onAppear {
                self.restoreFormState()
                self.updateScore(self.score)
            }
    }
    
    private func modifiedConstraints() -> ViewConstraints {
        var constraints = self.constraints
        if (self.constraints.width == nil && self.constraints.height == nil) {
            constraints.height = 32
        } else {
            switch(self.model.style) {
            case .numberRange(let style):
                constraints.height = self.calculateHeight(style: style, width: constraints.width)
            }
        }
        return constraints
    }

    func calculateHeight(style: ScoreNumberRangeStyle, width: CGFloat?) -> CGFloat? {
        guard let width = width else {
            return nil
        }

        let count = Double((style.start...style.end).count)
        let spacing = (count - 1.0) * (style.spacing ?? 0.0)
        let remainingSpace = width - spacing
        if (remainingSpace <= 0) {
            return nil
        }
        return remainingSpace / count
    }

    private func updateScore(_ value: Int?) {
        self.score = value
        let isValid = value != nil || self.model.isRequired != true
        
        var attributeValue: AttributeValue?
        if let value = value {
          attributeValue = AttributeValue.number(Double(value))
        }
        
        let data = FormInputData(self.model.identifier,
                                 value: .score(value),
                                 attributeName: self.model.attributeName,
                                 attributeValue: attributeValue,
                                 isValid: isValid)
        
        self.formState.updateFormInput(data)
    }

    private func restoreFormState() {
        let formValue = self.formState.data.formValue(identifier: self.model.identifier)

        guard case let .score(value) = formValue,
              let value = value
        else {
            return
        }

        self.score = value
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
                            Shapes.shape(model: shapes[index], constraints: viewConstraints, colorScheme: colorScheme)
                        }
                        .opacity(isOn ? 1 : 0)
                    }
                    Text(String(self.value))
                        .textAppearance(style.bindings.selected.textAppearance)
                       
                }.opacity(isOn ? 1 : 0)
                
                Group {
                    if let shapes = style.bindings.unselected.shapes {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(model: shapes[index], constraints: viewConstraints, colorScheme: colorScheme)
                        }
                    }
                    Text(String(self.value))
                        .textAppearance(style.bindings.unselected.textAppearance)
                }
                .opacity(isOn ? 0 : 1)
               
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(height: self.viewConstraints.height)
        }
        .animation(Animation.easeInOut(duration: 0.05))
    }
    
}
