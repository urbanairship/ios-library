/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
@_spi(AirshipInternal) import AirshipBasement

@MainActor
struct AsyncViewController: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.thomasAssociatedLabelResolver) var associatedLabelResolver
    @EnvironmentObject var thomasState: ThomasState
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    
    let info: ThomasViewInfo.AsyncViewController
    let constraints: ViewConstraints

    @StateObject
    private var state: ThomasAsyncViewState

    @StateObject
    private var scopedStateCache: ScopedStateCache = ScopedStateCache()

    @State
    private var resolverForResponse: ThomasAssociatedLabelResolver?

    init(
        info: ThomasViewInfo.AsyncViewController,
        constraints: ViewConstraints,
        resolver: any AsyncViewResolver
    ) {
        self.info = info
        self.constraints = constraints
        self._state = StateObject(
            wrappedValue: ThomasAsyncViewState(
                properties: info.properties,
                resolver: resolver
            )
        )
    }

    var body: some View {
        Group {
            if let response = state.response {
                thomasEnvironment.viewFactory.createView(response, constraints: constraints)
                    .environment(\.thomasAssociatedLabelResolver, resolverForResponse)
            } else {
                thomasEnvironment.viewFactory.createView(info.properties.placeholder, constraints: constraints)
                    .constraints(constraints)
                    .thomasCommon(info)
                    .onAppear {
                        state.configure(thomasEnvironment: thomasEnvironment)
                        state.retry()
                    }
            }
        }
        .environmentObject(state)
        .environmentObject(
            scopedStateCache.getOrCreate {
                thomasState.with(asyncViewState: state)
            }
        )
        .id(info.properties.identifier)
        .airshipOnChangeOf(state.status) { status in
            guard case .loaded = status, let response = state.response else { return }
            resolverForResponse = associatedLabelResolver?.merging(
                viewInfo: response,
                environment: thomasEnvironment
            )
        }
    }
}
