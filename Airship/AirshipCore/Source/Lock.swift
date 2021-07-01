/* Copyright Airship and Contributors */

import Foundation

/**
 * @note For internal use only. :nodoc:
 */
public class Lock {
    private let lock = NSRecursiveLock()

    public init() {}
    
    public func sync(closure: () -> ()) {
        self.lock.lock()
        closure()
        self.lock.unlock()
    }
}
