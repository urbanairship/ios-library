import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
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
            .environment(\.layoutState, layoutState.override(pagerState: pagerState))
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .environmentObject(pagerState)
    }
}
