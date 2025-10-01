/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@MainActor
struct StateController: View {
    private let info: ThomasViewInfo.StateController
    private let constraints: ViewConstraints

    @EnvironmentObject
    private var state: ThomasState

    @StateObject
    private var mutableState: ThomasState.MutableState

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
