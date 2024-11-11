import Foundation
import SwiftUI


internal struct VisibilityViewModifier: ViewModifier {
    let visibilityInfo: ThomasVisibilityInfo

    @EnvironmentObject var viewState: ViewState

    @ViewBuilder
    func body(content: Content) -> some View {
        if isVisible() {
            content
        }
    }

    func isVisible() -> Bool {
        let predicate = visibilityInfo.invertWhenStateMatches
        guard predicate.evaluate(viewState.state) else {
            return visibilityInfo.defaultVisibility
        }
        return !visibilityInfo.defaultVisibility
    }
}


extension View {

    @ViewBuilder
    func thomasVisibility(_ visibilityInfo: ThomasVisibilityInfo?) -> some View {
        if let visibilityInfo = visibilityInfo {
            self.modifier(
                VisibilityViewModifier(visibilityInfo: visibilityInfo)
            )
        } else {
            self
        }
    }
}
