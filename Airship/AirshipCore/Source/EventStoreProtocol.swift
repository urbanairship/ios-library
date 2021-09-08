/* Copyright Airship and Contributors */

import Foundation

/// Event data store protocol. For internal use only.
/// :nodoc:
@objc(UAEventStoreProtocol)
public protocol EventStoreProtocol {
    @objc
    func save(_ event: Event, eventID: String, eventDate: Date, sessionID: String)

    @objc
    func fetchEvents(
        withLimit limit: Int,
        completionHandler: @escaping ([EventData]) -> Void
    )

    @objc
    func deleteEvents(withIDs eventIDs: [String]?)

    @objc
    func deleteAllEvents()

    @objc
    func trimEvents(toStoreSize maxSize: UInt)
}
