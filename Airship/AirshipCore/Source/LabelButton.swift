/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct LabelButton : View {
    let model: LabelButtonModel
    let constraints: ViewConstraints
    @Environment(\.layoutState) var layoutState

    init(model: LabelButtonModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    var body: some View {
        Button(action: {}) {
            Label(model: self.model.label, constraints: constraints)
                .constraints(constraints, fixedSize: true)
                .applyIf(self.constraints.height == nil) { view in
                    view.padding([.bottom, .top], 12)
                }
                .applyIf(self.constraints.width == nil) { view in
                    view.padding([.leading, .trailing], 12)
                }
                .background(self.model.backgroundColor)
                .border(self.model.border)
                .accessible(self.model)
        }
        .buttonClick(self.model.identifier,
                     buttonDescription: self.model.contentDescription ?? self.model.label.text,
                     behaviors: self.model.clickBehaviors,
                     actions: self.model.actions)
        .common(self.model)
        .buttonStyle(PlainButtonStyle())
        .environment(\.layoutState,
                      layoutState.override(buttonState: ButtonState(identifier: self.model.identifier)))

    }
}
