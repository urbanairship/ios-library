/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct StateController: View {
    let info: ThomasViewInfo.StateController
    let constraints: ViewConstraints
    @EnvironmentObject var state: ThomasState
    @StateObject var mutableState: ThomasState.MutableState = ThomasState.MutableState()

    init(info: ThomasViewInfo.StateController, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info)
            .environmentObject(state.copy(mutableState: mutableState))
    }
}
