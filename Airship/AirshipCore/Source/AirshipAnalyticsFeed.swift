/* Copyright Airship and Contributors */

import Foundation

/// For internal use only. :nodoc:
public final class AirshipAnalyticsFeed: Sendable {
    private let isEnabled:  @Sendable () -> Bool

    public init(isEnabled: @Sendable @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    public convenience init(privacyManager: any AirshipPrivacyManager, isAnalyticsEnabled: Bool) {
        self.init(
            isEnabled: { [weak privacyManager] in
                return privacyManager?.isEnabled(.analytics) == true && isAnalyticsEnabled
            }
        )
    }

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

    @discardableResult
    func notifyEvent(_ event: Event) async -> Bool {
        guard isEnabled() else {
            return false
        }

        await channel.send(event)
        return true 
    }
}
