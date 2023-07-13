/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct AirshipCheckboxToggleStyle: ToggleStyle {
    let viewConstraints: ViewConstraints
    let model: CheckboxToggleStyleModel
    let colorScheme: ColorScheme
    let disabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        let isOn = configuration.isOn
        let binding = isOn ? model.bindings.selected : model.bindings.unselected

        var constraints = self.viewConstraints
        constraints.width = constraints.width ?? 24
        constraints.height = constraints.height ?? 24
        constraints.isVerticalFixedSize = true
        constraints.isHorizontalFixedSize = true

        return Button(action: { configuration.isOn.toggle() }) {
            ZStack {
                if let shapes = binding.shapes {
                    if binding == model.bindings.selected {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(
                                model: shapes[index],
                                constraints: constraints,
                                colorScheme: colorScheme
                            )
                        }
                        .applyIf(disabled) {  view in
                            view.colorMultiply(HexColor.disabled.toColor())
                        }
                    } else {
                        ForEach(0..<shapes.count, id: \.self) { index in
                            Shapes.shape(
                                model: shapes[index],
                                constraints: constraints,
                                colorScheme: colorScheme
                            )
                        }
                    }
                }

                if let iconModel = binding.icon {
                    Icons.icon(model: iconModel, colorScheme: colorScheme)
                }
            }
            .constraints(constraints, fixedSize: true)
            .animation(Animation.easeInOut(duration: 0.05))
        }
    }
}
