/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
struct StateController: View {
    let info: ThomasViewInfo.StateController
    let constraints: ViewConstraints

    @EnvironmentObject
    private var state: ThomasState
    
    @StateObject
    private var scopedStateCache: ScopedStateCache = ScopedStateCache()
    
    @StateObject
    private var mutableState: ThomasState.MutableState
    
    init(
        info: ThomasViewInfo.StateController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
        self._mutableState = StateObject(
            wrappedValue: ThomasState.MutableState(inititalState: info.properties.initialState)
        )
    }
    
    var body: some View {
        ViewFactory.createView(self.info.properties.view, constraints: constraints)
            .constraints(constraints)
            .thomasCommon(self.info)
            .environmentObject(
                scopedStateCache.getOrCreate {
                    state.with(mutableState: mutableState)
                }
            )
            .accessibilityElement(children: .contain)
    }
}
