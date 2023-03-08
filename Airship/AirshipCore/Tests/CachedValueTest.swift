/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class CachedValueTest: XCTestCase {

    let date = UATestDate(offset: 0, dateOverride: Date())

    func testValue() throws {
        let cachedValue = CachedValue<String>(date: date)
        cachedValue.set(value: "Hello!", expiresIn: 100)

        XCTAssertEqual(100.0, cachedValue.timeRemaining)
        XCTAssertEqual("Hello!", cachedValue.value)

        date.offset += 99

        XCTAssertEqual(1.0, cachedValue.timeRemaining)
        XCTAssertEqual("Hello!", cachedValue.value)

        date.offset += 1
        XCTAssertEqual(0, cachedValue.timeRemaining)
        XCTAssertNil(cachedValue.value)
    }

    func testValueExpiration() throws {
        let cachedValue = CachedValue<String>(date: date)
        cachedValue.set(value: "Hello!", expiration: date.now.addingTimeInterval(1.0))

        XCTAssertEqual(1.0, cachedValue.timeRemaining)
        XCTAssertEqual("Hello!", cachedValue.value)
    }
}
