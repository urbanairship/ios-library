/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct CachedListTest {

    let date = UATestDate(offset: 0, dateOverride: Date())

    @Test
    func testValue() throws {
        let cachedList = CachedList<String>(date: date)

        cachedList.append("foo", expiresIn: 100)
        #expect(["foo"] == cachedList.values)

        date.offset += 99

        cachedList.append("bar", expiresIn: 2)
        #expect(["foo", "bar"] == cachedList.values)

        date.offset += 1
        #expect(["bar"] == cachedList.values)

        date.offset += 1
        #expect([] == cachedList.values)

    }
}
