/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Condition
 */
@objc(UAPreferenceConditions)
public protocol Condition {
    
    /**
     * Condition type string.
     */
    @objc
    var type: String { get }
    
    /**
     * Condition type.
     */
    @objc
    var conditionType: ConditionType { get }
}


@objc(UAPreferenceNotificationOptInCondition)
public class NotificationOptInCondition: NSObject, Decodable, Condition {
    
    @objc(UANotificationOptInConditionStatus)
    public enum OptInStatus: Int {
        case optedIn
        case optedOut
    }
    
    @objc
    public let conditionType = ConditionType.notificationOptIn
    
    @objc
    public var type = ConditionType.notificationOptIn.stringValue
    
    @objc
    public let optInStatus: OptInStatus
    
    enum CodingKeys: String, CodingKey {
        case optInStatus = "when_status"
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let optInStatus = try container.decode(String.self, forKey: .optInStatus)

        switch optInStatus {
        case "opt_in":
            self.optInStatus = .optedIn
        case "opt_out":
            self.optInStatus = .optedOut
        default:
            throw AirshipErrors.error("Invalid status \(optInStatus)")
        }
    }
}

@objc(UAPreferenceConditionType)
public enum ConditionType: Int, CustomStringConvertible {
    case notificationOptIn
    
    var stringValue: String {
        switch self {
        case .notificationOptIn:
            return "notification_opt_in"
        }
    }
    
    static func fromString(_ value: String) throws -> ConditionType {
        switch value {
        case "notification_opt_in":
            return .notificationOptIn
        default:
            throw AirshipErrors.error("invalid condition \(value)")
        }
    }
    
    public var description: String {
        return stringValue
    }
}

/**
 * Typed conditions.
 */
public enum TypedConditions : Decodable {
    case notificationOptIn(NotificationOptInCondition)
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    var condition: Condition {
        switch(self) {
        case .notificationOptIn(let condition): return condition
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try ConditionType.fromString(container.decode(String.self, forKey: .type))
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case ConditionType.notificationOptIn:
            self = .notificationOptIn(try singleValueContainer.decode(NotificationOptInCondition.self))
        }
    }
}
