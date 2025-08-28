/* Copyright Airship and Contributors */



/// A class that manages a list of cached values, where each value has its own expiry.
final class CachedList<Value> where Value: Any {
    private let date: any AirshipDateProtocol
    private let lock = AirshipLock()
    private var cachedValues: [(Value, Date)] = []

    var values: [Value] {
        var result: [Value]!

        lock.sync {
            self.trim()
            result = self.cachedValues.map { $0.0 }
        }

        return result
    }

    func append(_ value: Value, expiresIn: TimeInterval) {
        let expiration = self.date.now.advanced(by: expiresIn)
        lock.sync {
            self.cachedValues.append((value, expiration))
        }
    }

    private func trim() {
        self.cachedValues.removeAll(where: {
            return self.date.now >= $0.1
        })
    }

    init(date: any AirshipDateProtocol = AirshipDate.shared) {
        self.date = date
    }
}
