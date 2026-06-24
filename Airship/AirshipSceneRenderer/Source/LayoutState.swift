/* Copyright Airship and Contributors */

import Foundation

struct LayoutState: Sendable {
    static let empty = LayoutState(
        pagerState: nil,
        formState: nil,
        buttonState: nil
    )

    var pagerState: PagerState?
    var formState: ThomasFormState?
    var buttonState: ButtonState?

    func override(pagerState: PagerState?) -> LayoutState {
        var context = self
        context.pagerState = pagerState
        return context
    }

    func override(formState: ThomasFormState?) -> LayoutState {
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
