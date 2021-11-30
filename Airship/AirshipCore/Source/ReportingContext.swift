/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
struct ReportingContext {
    static let empty = ReportingContext(layoutContext: nil, pagerState: nil, formState: nil)
    
    let layoutContext: JSON?
    var pagerState: PagerState?
    var formState: FormState?
    
    func override(pagerState: PagerState? = nil, formState: FormState? = nil) -> ReportingContext {
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

