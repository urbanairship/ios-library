/* Copyright Airship and Contributors */

import Foundation

/// Event manager protocol.
/// - Note: For internal use only. :nodoc:
@objc(UAEventManagerProtocol)
public protocol EventManagerProtocol {
    /// Flag indicating whether event manager uploads are enabled. Defaults to disabled. :nodoc:
    @objc
    var uploadsEnabled: Bool { get set }

    /// Event manager delegate. :nodoc:
    @objc
    weak var delegate: EventManagerDelegate? { get set }

    /// Adds an analytic event to be batched and uploaded to Airship. :nodoc:
    ///
    /// - Parameters:
    ///   - event: The analytic event.
    ///   - eventID: The event ID.
    ///   - eventDate: The event date.
    ///   - sessionID: The analytics session ID.
    @objc
    func add(_ event: Event, eventID: String, eventDate: Date, sessionID: String)

    /// Deletes all events and cancels any uploads in progress. :nodoc:
    @objc
    func deleteAllEvents()

    /// Schedules an analytic upload. :nodoc:
    @objc
    func scheduleUpload()
}
