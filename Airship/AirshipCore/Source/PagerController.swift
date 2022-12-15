import Foundation
import SwiftUI


struct PagerController: View {
    let model: PagerControllerModel
    let constraints: ViewConstraints
    @State var pagerState: PagerState
    @Environment(\.layoutState) var layoutState

    init(model: PagerControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self.pagerState = PagerState(identifier: model.identifier)
    }

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .environmentObject(pagerState)
            .environment(
                \.layoutState,
                layoutState.override(pagerState: pagerState)
            )
    }
}
