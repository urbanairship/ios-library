/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@Suite struct CachedValueTest {

    let date = UATestDate(offset: 0, dateOverride: Date())

    @Test
    func testValue() throws {
        let cachedValue = CachedValue<String>(date: date)
        cachedValue.set(value: "Hello!", expiresIn: 100)

        #expect(100.0 == cachedValue.timeRemaining)
        #expect("Hello!" == cachedValue.value)

        date.offset += 99

        #expect(1.0 == cachedValue.timeRemaining)
        #expect("Hello!" == cachedValue.value)

        date.offset += 1
        #expect(0 == cachedValue.timeRemaining)
        #expect(cachedValue.value == nil)
    }

    @Test
    func testValueExpiration() throws {
        let cachedValue = CachedValue<String>(date: date)
        cachedValue.set(value: "Hello!", expiration: date.now.advanced(by: 1.0))

        #expect(1.0 == cachedValue.timeRemaining)
        #expect("Hello!" == cachedValue.value)
    }
}
