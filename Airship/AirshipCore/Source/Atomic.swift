import Foundation

class Atomic<T: Equatable> {
    let lock = Lock()
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

    func compareAndSet(expected: T, value: T) -> Bool {
        var result = false
        lock.sync {
            if (expected == self._value) {
                self.value = value
                result = true
            }
        }
        return result
    }
}
