/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipAtomicValue<T: Sendable>: @unchecked Sendable {

    private let lock: AirshipLock = AirshipLock()
    private var _value: T

    public init(_ value: T) {
        self._value = value
    }

    public var value: T {
        lock.sync { self._value }
    }

    public func set(_ value: T) {
        lock.sync { self._value = value }
    }

    public func update(_ block: (inout T) -> Void) {
        lock.sync { block(&self._value) }
    }

    @discardableResult
    public func getAndUpdate(_ block: (inout T) -> Void) -> T {
        lock.sync {
            block(&self._value)
            return self._value
        }
    }
}

@_spi(AirshipInternal)
public extension AirshipAtomicValue where T: Equatable {

    @discardableResult
    func setValue(_ value: T, onChange: (() -> Void)? = nil) -> Bool {
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
