/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class AttributeUpdateTest: XCTestCase {

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

        XCTAssertEqual(original.attribute, decoded.attribute)
        XCTAssertEqual(
            original.jsonValue!,
            decoded.jsonValue!
        )
        XCTAssertEqual(original.date, decoded.date)

    }

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

        XCTAssertEqual(original.attribute, decoded.attribute)
        XCTAssertEqual(
            original.jsonValue!,
            decoded.jsonValue!
        )
        XCTAssertEqual(original.date, decoded.date)

    }
}
