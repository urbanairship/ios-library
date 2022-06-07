/* Copyright Airship and Contributors */

import Foundation

/**
 * A class that manages a list of cached values, where each value has its own expiry.
 */
class CachedList<Value> where Value : Any {
    private let date: AirshipDate
    private let maxCacheAge: TimeInterval
    private let lock = Lock()
    private var cachedValues: [(Value, Date)] = []

    var values: [Value] {
        get {
            var result: [Value]!

            lock.sync {
                self.trim()
                result = self.cachedValues.map { $0.0 }
            }

            return result
        }
    }

    func append(_ value: Value) {
        let expiration = self.date.now.addingTimeInterval(maxCacheAge)
        lock.sync {
            self.cachedValues.append((value, expiration))
        }
    }

    private func trim() {
        self.cachedValues.removeAll(where: {
            return self.date.now >= $0.1
        })
    }

    init(date: AirshipDate, maxCacheAge: TimeInterval) {
        self.date = date
        self.maxCacheAge = maxCacheAge
    }
}
