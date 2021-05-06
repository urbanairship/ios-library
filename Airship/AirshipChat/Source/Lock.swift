/* Copyright Airship and Contributors */

import Foundation

class Lock {
    private let lock = NSRecursiveLock()

    func sync(closure: () -> ()) {
        self.lock.lock()
        closure()
        self.lock.unlock()
    }
}
