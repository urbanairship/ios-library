import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
internal struct VisibilityViewModifier: ViewModifier {
    let visibilityInfo: VisibilityInfo

    @EnvironmentObject var viewState: ViewState

    @ViewBuilder
    func body(content: Content) -> some View {
        if (isVisible()) {
            content
        }
    }

    func isVisible() -> Bool {
        let predicate = visibilityInfo.invertWhenStateMatches
        if (predicate.evaluate(viewState.state)) {
            return !visibilityInfo.defaultVisibility
        } else {
            return visibilityInfo.defaultVisibility
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
extension View {

    @ViewBuilder
    func visibility(_ visibilityInfo: VisibilityInfo?) -> some View {
        if let visibilityInfo = visibilityInfo {
            self.modifier(VisibilityViewModifier(visibilityInfo: visibilityInfo))
        } else {
            self
        }
    }
}
