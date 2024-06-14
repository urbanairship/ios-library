/* Copyright Airship and Contributors */

import Foundation
@preconcurrency
import Combine

/// For internal use only. :nodoc:
public final class AirshipAnalyticsFeed: Sendable {
    public enum Event: Equatable, Sendable {
        case screen(screen: String?)
        case analytics(eventType: EventType, body: AirshipJSON, value: Double? = 1)
    }

    private let channel = AirshipAsyncChannel<Event>()

    public var updates: AsyncStream<Event> {
        get async {
            return await channel.makeStream()
        }
    }

    func notifyEvent(_ event: Event) async {
        await channel.send(event)
    }


    public init() {}
}
