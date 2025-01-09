/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public final class UAAnalytics: NSObject, Sendable {

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
    public func recordCustomEvent(_ event: UACustomEvent) {
        Airship.analytics.recordCustomEvent(event.customEvent)
    }
}
