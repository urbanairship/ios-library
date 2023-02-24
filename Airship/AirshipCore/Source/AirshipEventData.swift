import Foundation

/// Full airship event data
public struct AirshipEventData: Sendable, Equatable {

    // The event body
    public let body: AirshipJSON
    
    /// The event body unwrapped
    public var unwrappedBody: [String: Any] {
        return body.unWrap() as? [String: Any] ?? [:]
    }
    
    /// The event ID
    public let id: String

    /// The event date
    public let date: Date

    /// The SessionID
    public let sessionID: String

    /// The event type
    public let type: String
}
