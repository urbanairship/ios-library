/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
struct StateController: View {
    private let info: ThomasViewInfo.StateController
    private let constraints: ViewConstraints

    @EnvironmentObject
    private var thomasEnvironment: ThomasEnvironment
    
    init(
        info: ThomasViewInfo.StateController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
    }
    
    var body: some View {
        Content(
            info: self.info,
            constraints: self.constraints,
            thomasEnvironment: self.thomasEnvironment
        )
    }
    
    private struct Content: View {
        private let info: ThomasViewInfo.StateController
        private let constraints: ViewConstraints

        @EnvironmentObject
        private var state: ThomasState

        @EnvironmentObject private var thomasEnvironment: ThomasEnvironment

        @StateObject
        private var scopedStateCache: ScopedStateCache
        
        @StateObject
        private var mutableState: ThomasState.MutableState
        
        init(
            info: ThomasViewInfo.StateController,
            constraints: ViewConstraints,
            thomasEnvironment: ThomasEnvironment
        ) {
            self.info = info
            self.constraints = constraints
            
            let scopedStateCache = StateObject(
                wrappedValue: thomasEnvironment
                    .retrieveState(
                        identifier: info.identifier,
                        create: ScopedStateCache.init
                    )
            )
            
            self._scopedStateCache = scopedStateCache
            
            self._mutableState = StateObject(
                wrappedValue: ThomasState.MutableState(initialState: info.properties.initialState)
            )
            
        }
        
        var body: some View {
            thomasEnvironment.viewFactory
                .createView(self.info.properties.view, constraints: constraints)
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
}
