/* Copyright Airship and Contributors */



final class CachedValue<Value>: @unchecked Sendable where Value: Any {
    private let date: any AirshipDateProtocol
    private let lock = AirshipLock()
    private var expiration: Date?

    private var _value: Value?
    var value: Value? {
        get {
            var cachedValue: Value?
            lock.sync {
                guard let expiration = expiration,
                    self.date.now < expiration
                else {
                    self.expiration = nil
                    self._value = nil
                    return
                }

                cachedValue = _value
            }

            return cachedValue
        }
    }

    var timeRemaining: TimeInterval {
        var timeRemaining: TimeInterval = 0
        lock.sync {
            if let expiration = self.expiration {
                timeRemaining = max(0, expiration.timeIntervalSince(self.date.now))
            }

        }
        return timeRemaining
    }

    func set(value: Value, expiresIn: TimeInterval) {
        lock.sync {
            self.expiration = self.date.now.advanced(by: expiresIn)
            self._value = value
        }
    }

    func set(value: Value, expiration: Date) {
        lock.sync {
            self.expiration = expiration
            self._value = value
        }
    }

    func expireIf(predicate: (Value) -> Bool) {
        lock.sync {
            if let value = self._value, predicate(value) {
                self._value = nil
            }
        }
    }

    func expire() {
        lock.sync {
            self._value = nil
        }
    }

    init(date: any AirshipDateProtocol = AirshipDate.shared) {
        self.date = date
    }
}
