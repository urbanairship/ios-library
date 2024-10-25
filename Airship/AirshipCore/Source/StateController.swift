import Foundation
import SwiftUI


struct StateController: View {
    let model: StateControllerModel
    let constraints: ViewConstraints
    @StateObject var state: ViewState = ViewState()

    init(model: StateControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
            .environmentObject(state)
    }
}
