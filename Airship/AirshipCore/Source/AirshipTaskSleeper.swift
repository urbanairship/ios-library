/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol AirshipTaskSleeper: Sendable {
    func sleep(timeInterval: TimeInterval) async throws
}

/// NOTE: For internal use only. :nodoc:
public final class DefaultAirshipTaskSleeper: AirshipTaskSleeper {
    fileprivate static let shared: DefaultAirshipTaskSleeper = DefaultAirshipTaskSleeper()
    public func sleep(timeInterval: TimeInterval) async throws {
        if (timeInterval > 0) {
            try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
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
