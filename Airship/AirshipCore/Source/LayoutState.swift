/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
struct LayoutState {
    static let empty = LayoutState(pagerState: nil, formState: nil, buttonState: nil)
    
    var pagerState: PagerState?
    var formState: FormState?
    var buttonState: ButtonState?

    func override(pagerState: PagerState?) -> LayoutState {
        var context = self
        context.pagerState = pagerState
        return context
    }

    func override(formState: FormState?) -> LayoutState {
        var context = self
        context.formState = formState
        return context
    }

    func override(buttonState: ButtonState?) -> LayoutState {
        var context = self
        context.buttonState = buttonState
        return context
    }
}

