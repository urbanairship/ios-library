/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public final class AirshipAtomicValue<T: Sendable>: @unchecked Sendable {

    fileprivate let lock: AirshipLock = AirshipLock()
    fileprivate var _value: T

    public init(_ value: T) {
        self._value = value
    }

    public var value: T {
        get {
            var result: T!
            lock.sync {
                result = self._value
            }
            return result
        }

        set {
            lock.sync {
                self._value = newValue
            }
        }
    }

    public func update(onModify: (T) -> T) {
        lock.sync {
            self.value = onModify(self.value)
        }
    }
}

public extension AirshipAtomicValue where T: Equatable {

    @discardableResult
    func setValue(_ value: T, onChange:(() -> Void)? = nil) -> Bool {
        var changed = false
        lock.sync {
            if (self.value != value) {
                self.value = value
                changed = true
                onChange?()
            }
            self.value = value
        }
        return changed
    }


    @discardableResult
    func compareAndSet(expected: T, value: T) -> Bool {
        var result = false
        lock.sync {
            if expected == self._value {
                self.value = value
                result = true
            }
        }
        return result
    }
}




