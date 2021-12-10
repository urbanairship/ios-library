/* Copyright Airship and Contributors */

import Foundation

@objc(UAThomasDelegate)
public protocol ThomasDelegate {
    
    /// Called when a form is submitted
    /// - Parameters:
    ///     - formIdentifier: The form id
    ///     - formData: The form data.
    ///     - layoutState: The layout state.
    func onFormSubmitted(formIdentifier: String, formData: [String : Any], layoutState: [String : Any])
    
    /// Called when a form is displayed for the first time
    /// - Parameters:
    ///     - formIdentifier: The form id
    ///     - layoutState: The layout state.
    func onFormDisplayed(formIdentifier: String, layoutState: [String : Any])
    
    /// Called when a button is tapped.
    /// - Parameters:
    ///     - buttonIdentifier: The button id
    ///     - layoutState: The layout state.
    func onButtonTapped(buttonIdentifier: String, layoutState: [String : Any])
    
    /// Called when the view is dismissed.
    /// - Parameters:
    ///     - layoutState: The layout state.
    func onDismissed(layoutState: [String : Any])
    
    /// Called when the view is dismissed from a button tap.
    /// - Parameters:
    ///     - buttonIdentifier: The  button id.
    ///     - buttonDescription: The button description.
    ///     - cancel: If the view should be cancelled.
    ///     - layoutState: The layout state.
    func onDismissed(buttonIdentifier: String,
                     buttonDescription: String,
                     cancel: Bool,
                     layoutState: [String : Any])
    
    /// Called when a form is dismissed beceuse it timed out.
    /// - Parameters:
    ///     - layoutState: The layout state.
    func onTimedOut(layoutState: [String : Any])
    
    /// Called when a pager page is viewed.
    /// - Parameters:
    ///     - pagerIdentifier: The pager id.
    ///     - pageIndex: The page index
    ///     - pageCount: The page count
    ///     - completed: True if the last page of the pager has been viewed.
    ///     - layoutState: The layout state.
    func onPageViewed(pagerIdentifier: String,
                      pageIndex: Int,
                      pageCount: Int,
                      completed: Bool,
                      layoutState: [String : Any])
    
    /// Called when a pager page changed due to a swipe.
    /// - Parameters:
    ///     - pagerIdentifier: The pager identifier
    ///     - fromIndex: The originating index
    ///     - toIndex: The resulting index
    ///     - layoutState: The layout state.
    func onPageSwiped(pagerIdentifier: String, fromIndex: Int, toIndex: Int, layoutState: [String : Any])
}
