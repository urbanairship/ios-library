/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// Automation trigger types
public enum AutomationTriggerType: String, Sendable, Codable {
    /// Foreground
    case foreground
    
    /// Background
    case background

    /// Screen view
    case screen
    
    /// Version update
    case version

    /// App init
    case appInit = "app_init"

    // Region enter
    case regionEnter = "region_enter"

    /// Region exit
    case regionExit = "region_exit"

    /// Custom event count
    case customEventCount = "custom_event_count"

    /// Custom event value
    case customEventValue = "custom_event_value"

    /// Feature flag interaction
    case featureFlagInteraction = "feature_flag_interaction"

    /// Active session
    case activeSession = "active_session"
}


/// Automation trigger
public struct AutomationTrigger: Sendable, Codable, Equatable {
    /// The type
    public var type: AutomationTriggerType

    /// The trigger goal
    public var goal: Double

    /// Predicate to run on the event's data
    public var predicate: JSONPredicate?

    init(
        type: AutomationTriggerType,
        goal: Double,
        predicate: JSONPredicate? = nil
    ) {
        self.type = type
        self.goal = goal
        self.predicate = predicate
    }
}

public extension AutomationTrigger {
    static func activeSession(count: UInt) -> AutomationTrigger {
        return AutomationTrigger(type: .activeSession, goal: Double(count))
    }
    
    static func foreground(count: UInt) -> AutomationTrigger {
        return AutomationTrigger(type: .foreground, goal: Double(count))
    }
}
