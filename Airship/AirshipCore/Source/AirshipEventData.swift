import Foundation

/// Full airship event data
public struct AirshipEventData {

    /// The event body
    public let body: [String: Any]

    /// The event ID
    public let id: String

    /// The event date
    public let date: Date

    /// The SessionID
    public let sessionID: String

    /// The event type
    public let type: String
}
