/* Copyright Airship and Contributors */


import SwiftUI

@MainActor
struct StateController: View {
    let info: ThomasViewInfo.StateController
    let constraints: ViewConstraints
    @EnvironmentObject var state: ThomasState
    @StateObject var mutableState: ThomasState.MutableState
    init(
        info: ThomasViewInfo.StateController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
        let inititlaState = ThomasState.MutableState(
            inititalState: self.info.properties.initialState
        )
        self._mutableState = StateObject(
            wrappedValue: inititlaState
        )
    }
    
    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info)
            .environmentObject(state.copy(mutableState: mutableState))
    }
}
