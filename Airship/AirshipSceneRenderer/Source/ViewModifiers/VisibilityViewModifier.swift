import Foundation
import SwiftUI
import AirshipBasement


internal struct VisibilityViewModifier: ViewModifier {
    let visibilityInfo: ThomasVisibilityInfo

    @EnvironmentObject var thomasState: ThomasState

    @ViewBuilder
    func body(content: Content) -> some View {
        if isVisible() {
            content
        }
    }

    func isVisible() -> Bool {
        visibilityInfo.isVisible(state: thomasState.state)
    }
}

extension ThomasVisibilityInfo {
    /// Whether the view is shown in a given state.
    ///
    /// - Parameter state: the state the predicate is matched against
    /// - Returns: true when the view is shown
    func isVisible(state: AirshipJSON) -> Bool {
        guard invertWhenStateMatches.evaluate(json: state) else {
            return defaultVisibility
        }
        return !defaultVisibility
    }
}

