/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#endif

/// In-App messaging
public final class UAInAppMessaging: NSObject, Sendable {

    /// Display interval
    @MainActor
    public var displayInterval: TimeInterval {
        get {
            Airship.inAppAutomation.inAppMessaging.displayInterval
        }
        set {
            Airship.inAppAutomation.inAppMessaging.displayInterval = newValue
        }
    }
}


