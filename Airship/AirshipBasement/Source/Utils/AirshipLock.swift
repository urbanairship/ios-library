/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipLock: Sendable {
    private let _lock: NSLock = NSLock()

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
}
