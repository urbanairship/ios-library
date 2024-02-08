/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Automation trigger types
public enum EventAutomationTriggerType: String, Sendable, Codable, Equatable {
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

public enum CompoundAutomationTriggerType: String, Sendable, Codable, Equatable {
    case or
    case and
    case chain
}

public enum AutomationTrigger: Sendable, Codable, Equatable {
    case event(EventAutomationTrigger)
    case compound(CompoundAutomationTrigger)


    public func encode(to encoder: Encoder) throws {
        switch self {
        case .event(let trigger):
            try trigger.encode(to: encoder)
        case .compound(let trigger):
            try trigger.encode(to: encoder)
        }
    }

    enum CodingKeys: CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if CompoundAutomationTriggerType(rawValue: type) != nil {
            self = try .compound(CompoundAutomationTrigger(from: decoder))
        } else {
            self = try .event(EventAutomationTrigger(from: decoder))
        }
    }

    var id: String {
        switch self {
        case .compound(let trigger): return trigger.id
        case .event(let trigger): return trigger.id
        }
    }

    var goal: Double {
        switch self {
        case .compound(let trigger): return trigger.goal
        case .event(let trigger): return trigger.goal
        }
    }

    var type: String {
        switch self {
        case .compound(let trigger): return trigger.type.rawValue
        case .event(let trigger): return trigger.type.rawValue
        }
    }
}

extension AutomationTrigger {
    var shouldBackFillIdentifer: Bool {
        switch self {
        case .compound(_): return false
        case .event(let trigger): return trigger.allowBackfillID
        }
    }

    func backfilledIdentifier(executionType: TriggerExecutionType) -> AutomationTrigger {
        /// compound triggers should have IDs
        guard case .event(var eventTrigger) = self else { return self }
        eventTrigger.backfillIdentifier(executionType: executionType)
        return .event(eventTrigger)
    }
}

public struct EventAutomationTrigger: Sendable, Codable, Equatable {
    /// The type
    public var type: EventAutomationTriggerType

    /// The trigger goal
    public var goal: Double

    /// Predicate to run on the event's data
    public var predicate: JSONPredicate?

    var id: String

    /// Tracks if we should allow backfilling the ID. Will be true if the id was generated,, otherwise false.
    /// This field is only relevant when parsing JSON without an ID. Once it encodes/decodes
    /// an ID will be set and this will always be false.
    var allowBackfillID: Bool

    public init(
        type: EventAutomationTriggerType,
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
        type: EventAutomationTriggerType,
        goal: Double,
        predicate: JSONPredicate? = nil,
        resetOnFire: Bool? = nil,
        children: [AutomationTrigger] = []
    ) {
        self.type = type
        self.goal = goal
        self.predicate = predicate
        self.id = id

        // Programatically generated triggers should not allow backfilling the ID
        // even though we generated an ID. These triggers are not created from
        // remote-data so we just need to ensure they are unique.
        self.allowBackfillID = false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(EventAutomationTriggerType.self, forKey: .type)
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

    enum CodingKeys: String, CodingKey {
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

    mutating func backfillIdentifier(executionType: TriggerExecutionType) {
        guard self.allowBackfillID else {
            return
        }

        // Sha256(trigger_type:goal:execution_type:<stable json string of the predicate>?)

        var components: [String] = []
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

public struct CompoundAutomationTrigger: Sendable, Codable, Equatable {
    /// The ID
    var id: String

    /// The type
    var type: CompoundAutomationTriggerType

    /// The trigger goal
    var goal: Double

    var children: [Child]

    public struct Child: Sendable, Codable, Equatable {
        var trigger: AutomationTrigger
        var isSticky: Bool?
        var resetOnIncrement: Bool?

        enum CodingKeys: String, CodingKey {
            case trigger
            case isSticky = "is_sticky"
            case resetOnIncrement = "reset_on_increment"
        }
    }
}

public extension AutomationTrigger {
    static func activeSession(count: UInt) -> AutomationTrigger {
        return .event(EventAutomationTrigger(type: .activeSession, goal: Double(count)))
    }
    
    static func foreground(count: UInt) -> AutomationTrigger {
        return .event(EventAutomationTrigger(type: .foreground, goal: Double(count)))
    }
}
