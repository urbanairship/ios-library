/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UAAnalytics: NSObject {

    /// The current session ID.
    @objc
    public var sessionID: String {
        get {
            return Airship.analytics.sessionID
        }
    }

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @objc
    @MainActor
    public func trackScreen(_ screen: String?) {
        Airship.analytics.trackScreen(screen)
    }
    
    @objc
    public func recordCustomEvent(_ event: CustomEvent) {
        Airship.analytics.recordCustomEvent(event)
    }

    @objc
    public func recordRegionEvent(_ event: RegionEvent) {
        Airship.analytics.recordRegionEvent(event)
    }
}
