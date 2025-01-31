import Foundation
import SwiftUI

struct PagerController: View {
    let info: ThomasViewInfo.PagerController
    let constraints: ViewConstraints
    @StateObject var pagerState: PagerState
    @Environment(\.layoutState) var layoutState
    @Environment(\.isVoiceOverRunning) var isVoiceOverRunning

    @MainActor
    init(
        info: ThomasViewInfo.PagerController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
        self._pagerState = StateObject(wrappedValue: PagerState(
            identifier: info.properties.identifier,
            branching: info.properties.branching
        ))
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
            .environment(
                \.layoutState,
                 layoutState.override(pagerState: pagerState)
            )
    }
}
