/* Copyright Airship and Contributors */

public import Foundation

import AirshipCore
import AirshipAutomation

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


