/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// View factory. Inflates views based on type.
@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewFactory {
    @ViewBuilder
    static func createView(model: ViewModel, constraints: ViewConstraints) -> some View {
        switch (model) {
        case .container(let model):
            Container(model: model, constraints: constraints)
        case .linearLayout(let model):
            LinearLayout(model: model, constraints: constraints)
        case .scrollLayout(let model):
            ScrollLayout(model: model, constraints: constraints)
        case .label(let model):
            Label(model: model, constraints: constraints)
        case .media(let model):
            Media(model: model, constraints: constraints)
        case .labelButton(let model):
            LabelButton(model: model, constraints: constraints)
        case .emptyView(let model):
            EmptyView(model: model, constraints: constraints)
        case .formController(let model):
            FormController(model: model, constraints: constraints)
        case .npsController(let model):
            NpsController(model: model, constraints: constraints)
        case .textInput(let model):
            TextInput(model: model, constraints: constraints)
        case .pagerController(let model):
            PagerController(model: model, constraints: constraints)
        case .pagerIndicator(let model):
            PagerIndicator(model: model, constraints: constraints)
        case .pager(let model):
            Pager(model: model, constraints: constraints)
        #if !os(tvOS) && !os(watchOS)
        case .webView(let model):
            AirshipWebView(model: model, constraints: constraints)
        #endif
        case .imageButton(let model):
            ImageButton(model: model, constraints: constraints)
        case .checkbox(let model):
            Checkbox(model: model, constraints: constraints)
        case .checkboxController(let model):
            CheckboxController(model: model, constraints: constraints)
        case .toggle(let model):
            AirshipToggle(model: model, constraints: constraints)
        case .radioInputController(let model):
            RadioInputController(model: model, constraints: constraints)
        case .radioInput(let model):
            RadioInput(model: model, constraints: constraints)
        case .score(let model):
            Score(model: model, constraints: constraints)
        case .stateController(let model):
            StateController(model: model, constraints: constraints)
        }
    }
    
}

