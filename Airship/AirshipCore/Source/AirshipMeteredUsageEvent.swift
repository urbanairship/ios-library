/* Copyright Airship and Contributors */

import Foundation

/**
 * Internal only
 * :nodoc:
 */
public enum AirshipMeteredUsageType: String, Codable, Sendable {
    case inAppExperienceImpression = "iax_impression"
}

/**
 * Internal only
 * :nodoc:
 */
public struct AirshipMeteredUsageEvent: Codable, Sendable, Equatable {
    var eventID: String
    var entityID: String?
    var usageType: AirshipMeteredUsageType
    var product: String
    var reportingContext: AirshipJSON?
    var timestamp: Date?
    var contactID: String?

    public init(
        eventID: String,
        entityID: String?,
        usageType: AirshipMeteredUsageType,
        product: String,
        reportingContext: AirshipJSON?,
        timestamp: Date?,
        contactID: String?
    ) {
        self.eventID = eventID
        self.entityID = entityID
        self.usageType = usageType
        self.product = product
        self.reportingContext = reportingContext
        self.timestamp = timestamp
        self.contactID = contactID
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case usageType = "usage_type"
        case product
        case reportingContext = "reporting_context"
        case timestamp = "occurred"
        case entityID = "entity_id"
        case contactID = "contact_id"
    }
    
    func withDisabledAnalytics() -> AirshipMeteredUsageEvent {
        return AirshipMeteredUsageEvent(
            eventID: eventID,
            entityID: nil,
            usageType: usageType,
            product: product,
            reportingContext: nil,
            timestamp: nil,
            contactID: nil
        )
    }
}
