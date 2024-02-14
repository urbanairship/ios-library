/* Copyright Airship and Contributors */

import Foundation
@preconcurrency
import Combine

/// For internal use only. :nodoc:
public final class AirshipAnalyticsFeed: Sendable {
    public enum Event: Equatable, Sendable {
        case customEvent(body: AirshipJSON, value: Double)
        case regionEnter(body: AirshipJSON)
        case regionExit(body: AirshipJSON)
        case featureFlagInteraction(body: AirshipJSON)
        case screenChange(screen: String?)
    }

    private let subject = PassthroughSubject<Event, Never>()

    public var updates: AsyncStream<Event> {
        return  AsyncStream { continuation in
            let cancellable: AnyCancellable = subject.sink { value in
                continuation.yield(value)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public func notifyEvent(_ event: Event) {
        self.subject.send(event)
    }


    public init() {}
}
