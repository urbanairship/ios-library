import Foundation


final class Atomic<T: Equatable & Sendable>: @unchecked Sendable {

    private let lock = AirshipLock()
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
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

    func update(onModify: (T) -> T) {
        lock.sync {
            self.value = onModify(self.value)
        }
    }

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




