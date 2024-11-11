import Foundation
import SwiftUI


struct StateController: View {
    let info: ThomasViewInfo.StateController
    let constraints: ViewConstraints
    @StateObject var state: ViewState = ViewState()

    init(info: ThomasViewInfo.StateController, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info)
            .environmentObject(state)
    }
}
