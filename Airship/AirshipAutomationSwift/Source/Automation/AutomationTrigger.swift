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

    public var id: String

    /// Tracks if we should allow backfilling the ID. Will be true if the id was generated,, otherwise false.
    /// This field is only relevant when parsing JSON without an ID. Once it encodes/decodes
    /// an ID will be set and this will always be false.
    private var allowBackfillID: Bool

    public init(
        type: AutomationTriggerType,
        goal: Double,
        predicate: JSONPredicate? = nil
    ) {
        self.type = type
        self.goal = goal
        self.predicate = predicate
        self.id = UUID().uuidString

        // Programatically generated triggers should not allow backfilling the ID
        // even though we generated an ID. These triggers are not created from
        // remote-data so we just need to ensure they are unique.
        self.allowBackfillID = false
    }

    /// Used for tests
    init(
        id: String,
        type: AutomationTriggerType,
        goal: Double,
        predicate: JSONPredicate? = nil
    ) {
        self.type = type
        self.goal = goal
        self.predicate = predicate
        self.id = id
        self.allowBackfillID = false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(AutomationTriggerType.self, forKey: .type)
        self.goal = try container.decode(Double.self, forKey: .goal)
        self.predicate = try container.decodeIfPresent(JSONPredicate.self, forKey: .predicate)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        if let id = id {
            self.id = id
            self.allowBackfillID = false
        } else {
            self.id = UUID().uuidString
            self.allowBackfillID = true
        }
    }

    enum CodingKeys: CodingKey {
        case type
        case goal
        case predicate
        case id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.goal, forKey: .goal)
        try container.encodeIfPresent(self.predicate, forKey: .predicate)
        try container.encode(self.id, forKey: .id)
    }

    mutating func backfillIdentifier(
        parentTriggerID: String? = nil,
        executionType: TriggerExecutionType
    ) {
        guard self.allowBackfillID else {
            return
        }

        // Sha256(parent_trigger_id?:trigger_type:goal:execution_type:<stable json string of the predicate>?)

        var components: [String] = []
        if let parentTriggerID = parentTriggerID {
            components.append(parentTriggerID)
        }

        components.append(contentsOf: [self.type.rawValue, String(self.goal), executionType.rawValue])

        if let predicate = predicate, let json = try? JSONUtils.string(predicate, options: .sortedKeys) {
            components.append(json)
        }

        self.id = AirshipUtils.sha256Hash(
            input: components.joined(separator: ":")
        )
        self.allowBackfillID = false
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
