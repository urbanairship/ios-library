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
    
    var backendID: String?
    let uniqueID: String
    
    public var id: String {
        return backendID ?? uniqueID
    }

    init(
        type: AutomationTriggerType,
        goal: Double,
        predicate: JSONPredicate? = nil,
        id: String? = nil
    ) {
        self.type = type
        self.goal = goal
        self.predicate = predicate
        self.uniqueID = UUID().uuidString
        self.backendID = id ?? uniqueID
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(AutomationTriggerType.self, forKey: .type)
        self.goal = try container.decode(Double.self, forKey: .goal)
        self.predicate = try container.decodeIfPresent(JSONPredicate.self, forKey: .predicate)
        self.backendID = try container.decodeIfPresent(String.self, forKey: .backendID)
        self.uniqueID = try container.decodeIfPresent(String.self, forKey: .uniqueID) ?? UUID().uuidString
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
    
    //TODO: generate id based on "parentID:type:goal:executionType\(SHA256(predicate)"
}

public extension AutomationTrigger {
    static func activeSession(count: UInt) -> AutomationTrigger {
        return AutomationTrigger(type: .activeSession, goal: Double(count))
    }
    
    static func foreground(count: UInt) -> AutomationTrigger {
        return AutomationTrigger(type: .foreground, goal: Double(count))
    }
}
