/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
@objc(UAAnalyticsEventConsumerProtocol)
public protocol AnalyticsEventConsumerProtocol {
    
    /// Called when an event is added
    /// - Parameters:
    ///     - event: The event
    ///     - eventID: The event 's ID
    ///     - eventDate: The event's date
    func eventAdded(event: Event, eventID: String, eventDate: Date)
        
}
