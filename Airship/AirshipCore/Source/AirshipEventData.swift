/* Copyright Airship and Contributors */



/// Full airship event data
public struct AirshipEventData: Sendable, Equatable {

    // The event body
    public let body: AirshipJSON
    
    /// The event ID
    public let id: String

    /// The event date
    public let date: Date

    /// The SessionID
    public let sessionID: String

    /// The event type
    public let type: EventType
}

