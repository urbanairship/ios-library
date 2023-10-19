/* Copyright Airship and Contributors */

import Foundation

/**
 * Internal only
 * :nodoc:
 */
public enum AirshipMeteredUsageType: String, Codable, Sendable {
    case InAppExperienceImpresssion = "iax_impression"
}

/**
 * Internal only
 * :nodoc:
 */
public struct AirshipMeteredUsageEvent: Codable, Sendable, Equatable {
    let eventID: String
    let entityID: String?
    let type: AirshipMeteredUsageType
    let product: String
    let reportingContext: AirshipJSON?
    let timestamp: Date?
    let contactId: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case type
        case product
        case reportingContext = "reporting_context"
        case timestamp = "occurred"
        case entityID = "entity_id"
        case contactId = "contact_id"
    }
    
    func withDisabledAnalytics() -> AirshipMeteredUsageEvent {
        return AirshipMeteredUsageEvent(
            eventID: eventID,
            entityID: nil,
            type: type,
            product: product,
            reportingContext: nil,
            timestamp: nil,
            contactId: nil
        )
    }
}
