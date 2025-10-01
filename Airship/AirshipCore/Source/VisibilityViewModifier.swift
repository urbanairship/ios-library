import Foundation
import SwiftUI


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
        let predicate = visibilityInfo.invertWhenStateMatches
        guard predicate.evaluate(json: thomasState.state) else {
            return visibilityInfo.defaultVisibility
        }
        return !visibilityInfo.defaultVisibility
    }
}

