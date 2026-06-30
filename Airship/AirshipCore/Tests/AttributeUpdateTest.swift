/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite struct AttributeUpdateTest {

    @Test
    func testNumberCoding() throws {
        let original = AttributeUpdate(
            attribute: "some attribute",
            type: .set,
            jsonValue: 42,
            date: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder()
            .decode(AttributeUpdate.self, from: encoded)

        #expect(original.attribute == decoded.attribute)
        #expect(original.jsonValue! == decoded.jsonValue!)
        #expect(original.date == decoded.date)

    }

    @Test
    func testStringCoding() throws {
        let original = AttributeUpdate(
            attribute: "some attribute",
            type: .set,
            jsonValue: "neat",
            date: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder()
            .decode(AttributeUpdate.self, from: encoded)

        #expect(original.attribute == decoded.attribute)
        #expect(original.jsonValue! == decoded.jsonValue!)
        #expect(original.date == decoded.date)

    }
}
