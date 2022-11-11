/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class CachedListTest: XCTestCase {

    let date = UATestDate(offset: 0, dateOverride: Date())

    func testValue() throws {
        let cachedList = CachedList<String>(date: date, maxCacheAge: 100)

        cachedList.append("foo")
        XCTAssertEqual(["foo"], cachedList.values)

        date.offset += 99

        cachedList.append("bar")
        XCTAssertEqual(["foo", "bar"], cachedList.values)

        date.offset += 1
        XCTAssertEqual(["bar"], cachedList.values)
    }
}
