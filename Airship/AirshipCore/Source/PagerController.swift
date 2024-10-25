import Foundation
import SwiftUI



struct PagerController: View {
    let model: PagerControllerModel
    let constraints: ViewConstraints
    @StateObject var pagerState: PagerState
    @Environment(\.layoutState) var layoutState

    @MainActor
    init(model: PagerControllerModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
        self._pagerState = StateObject(wrappedValue: PagerState(identifier: model.identifier))
    }

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
            .environmentObject(pagerState)
            .environment(
                \.layoutState,
                layoutState.override(pagerState: pagerState)
            )
    }
}
