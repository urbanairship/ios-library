/* Copyright Airship and Contributors */

import Foundation

class CachedValue<Value> where Value : Any {
    private let date: AirshipDate
    private let maxCacheAge: TimeInterval
    private let lock = Lock()
    private var expiration: Date?

    private var _value: Value?
    var value: Value? {
        get {
            var cachedValue: Value?
            lock.sync {
                guard let expiration = expiration,
                      self.date.now < expiration else {
                          self.expiration = nil
                          self._value = nil
                          return
                      }
                
                cachedValue = _value
            }
            
            return cachedValue
        }
        set {
            lock.sync {
                self.expiration = self.date.now.addingTimeInterval(maxCacheAge)
                self._value = newValue
            }
        }
    }
    
    init(date: AirshipDate, maxCacheAge: TimeInterval) {
        self.date = date
        self.maxCacheAge = maxCacheAge
    }
}
