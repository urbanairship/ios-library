/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class MainActorMemoryStore<T: Sendable>: Sendable {
    private var state: [String: T] = [:]

    /// Sets the value for a given key
    /// - Parameters:
    ///     - value: The value to set
    ///     - key: The key
    public func setValue(_ value: T?, forKey key: String) {
        self.state[key] = value
    }

    /// Gets the state for the given key
    /// - Parameters:
    ///     - key: The key
    /// - Returns: The value if it exists
    public func value(forKey key: String) -> T? {
        return self.state[key]
    }
}
