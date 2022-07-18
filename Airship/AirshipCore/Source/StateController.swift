import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct StateController: View {
    let model: StateControllerModel
    let constraints: ViewConstraints
    @State var state: ViewState

    init(model: StateControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self.state = ViewState()
    }

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .environmentObject(state)
    }
}
