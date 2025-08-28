/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
public import AirshipCore
#endif

/**
 * Action to cancel automation schedules.
 *
 * This action is registered under the names cancel_scheduled_actions and ^csa.
 *
 * Expected argument values: String with the value "all" or a Dictionary with:
 *  - "groups": A schedule group or an array of schedule groups.
 *  - "ids": A schedule ID or an array of schedule IDs.
 *
 * Valid situations: ActionSituation.backgroundPush, .foregroundPush, .webViewInvocation, .manualInvocation, and .automation
 *
 * Result value: nil.
 */

public final class CancelSchedulesAction: AirshipAction {
    
    //used for tests
    private let overrideAutomation: InAppAutomation?
    
    /// Cancel schedules action names.
    public static let defaultNames: [String] = ["cancel_scheduled_actions", "^csa"]
    
    init(overrideAutomation: InAppAutomation? = nil) {
        self.overrideAutomation = overrideAutomation
    }
    
    var automation: InAppAutomation {
        return overrideAutomation ?? Airship.inAppAutomation
    }
    
    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation, 
            .backgroundPush,
            .foregroundPush,
            .webViewInvocation,
            .automation:
                return true
        default: return false
        }
    }
    
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let args: Arguments = try arguments.value.decode()
        
        let automation = self.automation
        
        if args.cancellAll {
            try await automation.cancelSchedulesWith(type: .actions)
            return nil
        }
        
        if let groups = args.groups {
            for item in groups {
                try await automation.cancelSchedules(group: item)
            }
        } 
        
        if let ids = args.scheduleIDs {
            try await automation.cancelSchedule(identifiers: ids)
        }
        
        return nil
    }
    
    fileprivate struct Arguments: Decodable, Sendable {
        static let all = "all"
        
        let cancellAll: Bool
        let scheduleIDs: [String]?
        let groups: [String]?
        
        enum CodingKeys: String, CodingKey {
            case ids = "ids"
            case groups = "groups"
        }
        
        init(from decoder: any Decoder) throws {
            func decodeSingleOrArray<T, K>(from container: KeyedDecodingContainer<K>, key: K) throws -> [T]? where T: Decodable {
                guard container.contains(key) else { return nil }
                do {
                    return try container.decode([T].self, forKey: key)
                } catch {
                    let value = try container.decode(T.self, forKey: key)
                    return [value]
                }
            }
            
            var scheduleIds: [String]?
            var groups: [String]?
            
            do {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                scheduleIds = try decodeSingleOrArray(from: container, key: .ids)
                groups = try decodeSingleOrArray(from: container, key: .groups)
                self.cancellAll = false
            } catch {
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                guard value == Self.all else {
                    throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Invalid cancel action"))
                }
                self.cancellAll = true
            }
            
            if !cancellAll, scheduleIds == nil, groups == nil {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid cacncel action"))
            }
            
            self.scheduleIDs = scheduleIds
            self.groups = groups
        }
    }
}
