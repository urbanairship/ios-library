/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#endif

/**
 * Provides a control interface for creating, canceling and executing in-app automations.
 */
@objc
public final class UAInAppAutomation: NSObject, Sendable {
        
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
