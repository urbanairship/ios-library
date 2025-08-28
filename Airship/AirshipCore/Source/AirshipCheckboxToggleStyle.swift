/* Copyright Airship and Contributors */


import SwiftUI

struct AirshipCheckboxToggleStyle: ToggleStyle {
    let viewConstraints: ViewConstraints
    let info: ThomasToggleStyleInfo.Checkbox

    func makeBody(configuration: Self.Configuration) -> some View {
        SwitchView(configuration: configuration, info: info, viewConstraints: viewConstraints)
    }

    struct SwitchView: View {
        let configuration: ToggleStyle.Configuration
        let info: ThomasToggleStyleInfo.Checkbox
        let viewConstraints: ViewConstraints

        @Environment(\.isEnabled) var isEnabled
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            let binding = configuration.isOn ? info.bindings.selected : info.bindings.unselected
            var constraints = self.viewConstraints
            constraints.width = constraints.width ?? 24
            constraints.height = constraints.height ?? 24
            constraints.isVerticalFixedSize = true
            constraints.isHorizontalFixedSize = true

            return Button(action: { configuration.isOn.toggle() }) {
                ZStack {
                    if let shapes = binding.shapes {
                        if binding == info.bindings.selected {
                            ForEach(0..<shapes.count, id: \.self) { index in
                                Shapes.shape(
                                    info: shapes[index],
                                    constraints: constraints,
                                    colorScheme: colorScheme
                                )
                            }
                            .airshipApplyIf(!isEnabled) {  view in
                                view.colorMultiply(ThomasConstants.disabledColor)
                            }
                        } else {
                            ForEach(0..<shapes.count, id: \.self) { index in
                                Shapes.shape(
                                    info: shapes[index],
                                    constraints: constraints,
                                    colorScheme: colorScheme
                                )
                            }
                        }
                    }

                    if let iconModel = binding.icon {
                        Icons.icon(info: iconModel, colorScheme: colorScheme)
                    }
                }
                .constraints(constraints, fixedSize: true)
                .animation(Animation.easeInOut(duration: 0.05), value: configuration.isOn)
                .addSelectedTrait(configuration.isOn)
            }
#if os(tvOS)
            .buttonStyle(TVButtonStyle())
#endif
        }

    }
}
