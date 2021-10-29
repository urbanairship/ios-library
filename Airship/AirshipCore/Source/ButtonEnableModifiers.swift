/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ValidFormButtonEnableBehavior: ViewModifier {
    @EnvironmentObject var formState: FormState
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.disabled(!formState.data.isValid)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerNextButtonEnableBehavior: ViewModifier {
    @EnvironmentObject var pagerState: PagerState
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.disabled(pagerState.index >= (pagerState.pages - 1))
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerPreviousButtonEnableBehavior: ViewModifier {
    @EnvironmentObject var pagerState: PagerState
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content.disabled(pagerState.index <= 0)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func enableButton(_ behaviors: [ButtonEnableBehavior]?) -> some View {
        if let behaviors = behaviors {
            self.applyIf(behaviors.contains(.formValidation)) { view in
                view.modifier(ValidFormButtonEnableBehavior())
            }
            .applyIf(behaviors.contains(.pagerNext)) { view in
                view.modifier(PagerNextButtonEnableBehavior())
            }
            .applyIf(behaviors.contains(.pagerPrevious)) { view in
                view.modifier(PagerPreviousButtonEnableBehavior())
            }
        } else {
            self
        }
    }
}

