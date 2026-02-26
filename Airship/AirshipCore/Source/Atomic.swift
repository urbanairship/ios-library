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
            self._value = onModify(self._value)
        }
    }
}

public extension AirshipAtomicValue where T: Equatable {

    @discardableResult
    func setValue(_ value: T, onChange:(() -> Void)? = nil) -> Bool {
        return lock.sync {
            guard self._value != value else { return false }
            self._value = value
            onChange?()
            return true
        }
    }


    @discardableResult
    func compareAndSet(expected: T, value: T) -> Bool {
        return lock.sync {
            guard self._value == expected else { return false }
            self._value = value
            return true
        }
    }
}




