/* Copyright Airship and Contributors */



struct ThomasAutomatedAction: Codable, Equatable, Sendable {
    var identifier: String
    var delay: Double?
    var actions: [ThomasActionsPayload]?
    var behaviors: [ThomasButtonClickBehavior]?
    var reportingMetadata: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case identifier
        case delay
        case actions
        case behaviors
        case reportingMetadata = "reporting_metadata"
    }
}
