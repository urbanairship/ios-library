/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#endif

/**
 * In-App Automation
 */
@objc
public final class UAInAppAutomation: NSObject, Sendable {

    override init() {
        super.init()
    }
    
    /// In-App messaging
    @objc
    public let inAppMessaging: UAInAppMessaging = UAInAppMessaging()

    /// Paused state of in-app automation.
    @MainActor
    public var isPaused: Bool {
        get {
            return Airship.inAppAutomation.isPaused
        }
        set {
            Airship.inAppAutomation.isPaused = newValue
        }
    }
    
}
