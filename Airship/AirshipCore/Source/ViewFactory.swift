/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// View factory. Inflates views based on type.
@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewFactory {
    @ViewBuilder
    static func createView(model: BaseViewModel, constraints: ViewConstraints) -> some View {
        switch (model) {
        case let containerModel as ContainerModel:
            Container(model: containerModel, constraints: constraints)
        case let linearLayoutModel as LinearLayoutModel:
            LinearLayout(model: linearLayoutModel, constraints: constraints)
        case let scrollLayoutModel as ScrollLayoutModel:
            ScrollLayout(model: scrollLayoutModel, constraints: constraints)
        case let labelModel as LabelModel:
            Label(model: labelModel, constraints: constraints)
        case let buttonModel as LabelButtonModel:
            LabelButton(model: buttonModel, constraints: constraints)
        case let emptyViewModel as EmptyViewModel:
            EmptyView(model: emptyViewModel, constraints: constraints)
        case let formControllerModel as FormControllerModel:
            FormController(model: formControllerModel, constraints: constraints)
        case let npsControllerModel as NpsControllerModel:
            NpsController(model: npsControllerModel, constraints: constraints)
        case let textInputModel as TextInputModel:
            TextInput(model: textInputModel, constraints: constraints)
        default:
            Text("\(model.type.rawValue) not supported")
        }
    }
}

