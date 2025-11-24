/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// View factory. Inflates views based on type.

struct ViewFactory {
    @MainActor
    @ViewBuilder
    static func createView(
        _ viewInfo: ThomasViewInfo,
        constraints: ViewConstraints
    ) -> some View {
        switch viewInfo {
        case .container(let info):
            Container(info: info, constraints: constraints)
        case .linearLayout(let info):
            LinearLayout(info: info, constraints: constraints)
        case .scrollLayout(let info):
            ScrollLayout(info: info, constraints: constraints)
        case .label(let info):
            Label(info: info, constraints: constraints)
        case .media(let info):
            Media(info: info, constraints: constraints)
        case .labelButton(let info):
            LabelButton(info: info, constraints: constraints)
        case .emptyView(let info):
            AirshipEmptyView(info: info, constraints: constraints)
        case .formController(let info):
            FormController(info: .form(info), constraints: constraints)
        case .npsController(let info):
            FormController(info: .nps(info), constraints: constraints)
        case .textInput(let info):
            TextInput(info: info, constraints: constraints)
        case .pagerController(let info):
            PagerController(info: info, constraints: constraints)
        case .pagerIndicator(let info):
            PagerIndicator(info: info, constraints: constraints)
        case .storyIndicator(let info):
            StoryIndicator(info: info, constraints: constraints)
        case .pager(let info):
            Pager(info: info, constraints: constraints)
        #if !os(tvOS) && !os(watchOS)
        case .webView(let info):
            AirshipWebView(info: info, constraints: constraints)
        #endif
        case .imageButton(let info):
            ImageButton(info: info, constraints: constraints)
        case .stackImageButton(let info):
            StackImageButton(info: info, constraints: constraints)
        case .checkbox(let info):
            Checkbox(info: info, constraints: constraints)
        case .checkboxController(let info):
            CheckboxController(info: info, constraints: constraints)
        case .toggle(let info):
            AirshipToggle(info: info, constraints: constraints)
        case .radioInputController(let info):
            RadioInputController(info: info, constraints: constraints)
        case .radioInput(let info):
            RadioInput(info: info, constraints: constraints)
        case .score(let info):
            Score(info: info, constraints: constraints)
        case .stateController(let info):
            StateController(info: info, constraints: constraints)
        case .customView(let info):
            CustomView(info: info, constraints: constraints)
        case .buttonLayout(let info):
            ButtonLayout(info: info, constraints: constraints)
        case .basicToggleLayout(let info):
            BasicToggleLayout(info: info, constraints: constraints)
        case .checkboxToggleLayout(let info):
            CheckboxToggleLayout(info: info, constraints: constraints)
        case .radioInputToggleLayout(let info):
            RadioInputToggleLayout(info: info, constraints: constraints)
        case .iconView(let info):
            IconView(info: info, constraints: constraints)
        case .scoreController(let info):
            ScoreController(info: info, constraints: constraints)
        case .scoreToggleLayout(let info):
            ScoreToggleLayout(info: info, constraints: constraints)
        }
    }
}
