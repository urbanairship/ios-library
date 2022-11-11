/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class CachedValueTest: XCTestCase {

    let date = UATestDate(offset: 0, dateOverride: Date())

    func testValue() throws {
        let cachedValue = CachedValue<String>(date: date, maxCacheAge: 100)
        cachedValue.value = "Hello!"

        XCTAssertEqual("Hello!", cachedValue.value)

        date.offset += 99

        XCTAssertEqual("Hello!", cachedValue.value)

        date.offset += 1
        XCTAssertNil(cachedValue.value)
    }
}
