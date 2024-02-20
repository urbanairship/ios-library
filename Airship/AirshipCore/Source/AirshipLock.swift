/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public final class AirshipLock: Sendable {
    private let _lock = NSRecursiveLock()

    public init() {}

    public func sync(closure: () -> Void) {
        self._lock.withLock {
            closure()
        }
    }
    
    public func sync<T>(closure: () -> T) -> T {
        return self._lock.withLock {
            return closure()
        }
    }

    public func lock() {
        self._lock.lock()
    }

    public func unlock() {
        self._lock.unlock()
    }
}
