/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
struct LayoutState {
    static let empty = LayoutState(pagerState: nil, formState: nil)
    
    var pagerState: PagerState?
    var formState: FormState?
    
    func override(pagerState: PagerState? = nil, formState: FormState? = nil) -> LayoutState {
        var context = self
        if (pagerState != nil) {
            context.pagerState = pagerState
        }
        
        if (formState != nil) {
            context.formState = formState
        }
        
        return context
    }
}

