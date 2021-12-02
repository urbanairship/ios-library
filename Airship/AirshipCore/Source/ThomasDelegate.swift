/* Copyright Airship and Contributors */

import Foundation

@objc(UAThomasDelegate)
public protocol ThomasDelegate {
    
    /// Called when a view is displayed
    /// - Parameters:
    ///     - reportingContext: The reporting context.
    func onDisplayed(reportingContext: [String : Any])
    
    /// Called when a form is submitted
    /// - Parameters:
    ///     - formIdentifier: The form id
    ///     - formData: The form data.
    ///     - reportingContext: The reporting context.
    func onFormSubmitted(formIdentifier: String, formData: [String : Any], reportingContext: [String : Any])
    
    /// Called when a form is displayed for the first time
    /// - Parameters:
    ///     - formIdentifier: The form id
    ///     - reportingContext: The reporting context.
    func onFormDisplayed(formIdentifier: String, reportingContext: [String : Any])
    
    /// Called when a button is tapped.
    /// - Parameters:
    ///     - buttonIdentifier: The button id
    func onButtonTapped(buttonIdentifier: String, reportingContext: [String : Any])
    
    /// Called when the view is dismissed.
    /// - Parameters:
    ///     - reportingContext: The reporting context.
    func onDismissed(reportingContext: [String : Any])
    
    /// Called when the view is dismissed from a button tap.
    /// - Parameters:
    ///     - buttonIdentifier: The  button id.
    ///     - buttonDescription: The button description.
    ///     - cancel: If the view should be cancelled.
    ///     - reportingContext: The reporting context.
    func onDismissed(buttonIdentifier: String,
                     buttonDescription: String,
                     cancel: Bool,
                     reportingContext: [String : Any])
    
    /// Called when a form is dismissed beceuse it timed out.
    /// - Parameters:
    ///     - reportingContext: The reporting context.
    func onTimedOut(reportingContext: [String : Any])
    
    /// Called when a pager page is viewed.
    /// - Parameters:
    ///     - pagerIdentifier: The pager id.
    ///     - pageIndex: The page index
    ///     - pageCount: The page count
    ///     - completed: True if the last page of the pager has been viewed.
    ///     - reportingContext: The reporting context.
    func onPageViewed(pagerIdentifier: String,
                      pageIndex: Int,
                      pageCount: Int,
                      completed: Bool,
                      reportingContext: [String : Any])
    
    /// Called when a pager page changed due to a swipe.
    /// - Parameters:
    ///     - pagerIdentifier: The pager identifier
    ///     - fromIndex: The originating index
    ///     - toIndex: The resulting index
    ///     - reportingContext: The reporting context.
    func onPageSwiped(pagerIdentifier: String, fromIndex: Int, toIndex: Int, reportingContext: [String : Any])
}
