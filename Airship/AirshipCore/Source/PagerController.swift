import Foundation
import SwiftUI

@MainActor
struct PagerController: View {
    let info: ThomasViewInfo.PagerController
    let constraints: ViewConstraints

    @EnvironmentObject var formDataCollector: ThomasFormDataCollector
    @EnvironmentObject var environment: ThomasEnvironment

    init(
        info: ThomasViewInfo.PagerController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        Content(
            info: self.info,
            constraints: constraints,
            environment: environment,
            parentFormDataCollector: self.formDataCollector
        )
    }

    @MainActor
    struct Content: View {
        let info: ThomasViewInfo.PagerController
        let constraints: ViewConstraints

        @ObservedObject var pagerState: PagerState
        @StateObject var formDataCollector: ThomasFormDataCollector

        @Environment(\.layoutState) var layoutState
        @Environment(\.isVoiceOverRunning) var isVoiceOverRunning


        init(
            info: ThomasViewInfo.PagerController,
            constraints: ViewConstraints,
            environment: ThomasEnvironment,
            parentFormDataCollector: ThomasFormDataCollector
        ) {
            self.info = info
            self.constraints = constraints

            // Use the environment to create or retrieve the state in case the view
            // stack changes and we lose our state.
            let pagerState = environment.retrieveState(identifier: info.properties.identifier) {
                PagerState(
                    identifier: info.properties.identifier,
                    branching: info.properties.branching
                )
            }

            self._pagerState = ObservedObject(wrappedValue: pagerState)

            self._formDataCollector = StateObject(
                wrappedValue: parentFormDataCollector.copy(pagerState: pagerState)
            )
        }

        var body: some View {
            ViewFactory.createView(self.info.properties.view, constraints: constraints)
                .constraints(constraints)
                .airshipOnChangeOf(self.isVoiceOverRunning, initial: true) { value in
                    pagerState.isVoiceOverRunning = value
                }
                .onAppear {
                    pagerState.isVoiceOverRunning = isVoiceOverRunning
                }
                .thomasCommon(self.info)
                .environmentObject(pagerState)
                .environmentObject(self.formDataCollector)
                .environment(\.layoutState, layoutState.override(pagerState: pagerState))
        }
    }
}
