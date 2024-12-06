/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol AirshipTaskSleeper: Sendable {
    func sleep(timeInterval: TimeInterval) async throws
}

/// NOTE: For internal use only. :nodoc:
public final class DefaultAirshipTaskSleeper: AirshipTaskSleeper {
    fileprivate static let shared: DefaultAirshipTaskSleeper = DefaultAirshipTaskSleeper()
    private static let maxDelayInterval: TimeInterval = 30

    private let date: any AirshipDateProtocol
    private let onSleep: @Sendable (TimeInterval) async throws -> Void

    init(
        date: any AirshipDateProtocol = AirshipDate.shared,
        onSleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
            try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
        }
    ) {
        self.date = date
        self.onSleep = onSleep
    }

    public func sleep(timeInterval: TimeInterval) async throws {
        let start: Date = date.now

        /// Its unclear what clock is being used for Task.sleep(nanoseconds:) and we have had issues
        /// with really long delays not firing at the right period of time. This works around those issues by
        /// breaking long sleeps into chunks.
        var remaining = timeInterval - date.now.timeIntervalSince(start)
        while remaining > 0, !Task.isCancelled {
            let interval = min(remaining, Self.maxDelayInterval)
            try await onSleep(interval)
            remaining = timeInterval - date.now.timeIntervalSince(start)
        }
    }
}

/// NOTE: For internal use only. :nodoc:
public extension AirshipTaskSleeper where Self == DefaultAirshipTaskSleeper {
    /// Default style
    static var shared: Self {
        return DefaultAirshipTaskSleeper.shared
    }
}
