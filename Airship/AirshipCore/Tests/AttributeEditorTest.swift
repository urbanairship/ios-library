/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class AttributeEditorTest: XCTestCase {

    var date: UATestDate!

    override func setUp() {
        self.date = UATestDate()
    }

    func testEditor() throws {
        var out: [AttributeUpdate]?

        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        editor.remove("bar")
        editor.set(string: "neat", attribute: "bar")

        editor.set(int: 10, attribute: "foo")
        editor.remove("foo")

        let applyDate = Date(timeIntervalSince1970: 1)
        self.date.dateOverride = applyDate
        editor.apply()

        XCTAssertEqual(2, out?.count)

        let foo = out?.first { $0.attribute == "foo" }
        let bar = out?.first { $0.attribute == "bar" }

        XCTAssertEqual(AttributeUpdateType.remove, foo?.type)
        XCTAssertEqual(applyDate, foo?.date)
        XCTAssertNil(foo?.jsonValue?.unWrap())

        XCTAssertEqual(AttributeUpdateType.set, bar?.type)
        XCTAssertEqual("neat", bar?.jsonValue?.unWrap() as? String)
        XCTAssertEqual(applyDate, foo?.date)
    }

    func testDateAttribute() throws {
        var out: [AttributeUpdate]?

        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        editor.set(date: Date(timeIntervalSince1970: 10000), attribute: "date")
        let applyDate = Date(timeIntervalSince1970: 1)
        self.date.dateOverride = applyDate
        editor.apply()

        let attribute = out?.first

        XCTAssertEqual(AttributeUpdateType.set, attribute?.type)
        XCTAssertEqual(applyDate, attribute?.date)
        XCTAssertEqual(
            "1970-01-01T02:46:40",
            attribute?.jsonValue?.unWrap() as! String
        )
    }

    func testEditorNoAttributes() throws {
        var out: [AttributeUpdate]?

        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        editor.apply()

        XCTAssertEqual(0, out?.count)
    }

    func testEditorEmptyString() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }
        editor.set(string: "", attribute: "cool")
        editor.set(string: "cool", attribute: "")
        editor.apply()

        XCTAssertEqual(0, out?.count)
    }

    func testSetJSONAttributeNoExpiration() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        let payload: [String: AirshipJSON] = [
            "flavor": .string("vanilla"),
            "rating": .number(5.0),
            "available": .bool(true),
        ]

        try editor.set(
            json: payload,
            attribute: "icecream",
            instanceID: "store-123"
        )

        let now = Date(timeIntervalSince1970: 10)
        self.date.dateOverride = now
        editor.apply()

        XCTAssertEqual(1, out?.count)
        guard let first = out?.first else {
            XCTFail("missing update")
            return
        }

        XCTAssertEqual(AttributeUpdateType.set, first.type)
        XCTAssertEqual("icecream#store-123", first.attribute)
        XCTAssertEqual(now, first.date)

        let unwrapped = first.jsonValue?.unWrap() as? [String: AnyHashable]
        XCTAssertEqual(3, unwrapped?.count)
        XCTAssertEqual("vanilla", unwrapped?["flavor"] as? String)
        XCTAssertEqual(5.0, unwrapped?["rating"] as? Double)
        XCTAssertEqual(true, unwrapped?["available"] as? Bool)
        XCTAssertNil(unwrapped?["exp"], "Unexpected expiry key present")
    }

    func testSetJSONAttributeWithExpiration() throws {
        var out: [AttributeUpdate]? = nil
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        let payload: [String: AirshipJSON] = [
            "size": .string("large"),
        ]

        let expiration = Date(timeIntervalSince1970: 1000)

        try editor.set(
            json: payload,
            attribute: "coffee",
            instanceID: "order-123",
            expiration: expiration
        )

        self.date.dateOverride = Date(timeIntervalSince1970: 20)
        editor.apply()

        guard let update = out?.first else {
            XCTFail("Missing update")
            return
        }

        XCTAssertEqual("coffee#order-123", update.attribute)
        XCTAssertEqual(AttributeUpdateType.set, update.type)

        let dict = update.jsonValue?.unWrap() as? [String: AnyHashable]
        XCTAssertEqual("large", dict?["size"] as? String)

        if let exp = dict?["exp"] as? Double {
            XCTAssertEqual(expiration.timeIntervalSince1970, exp, accuracy: 0.001)
        } else {
            XCTFail("Missing expiration key in payload")
        }
    }

    func testRemoveJSONAttribute() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        try editor.remove(attribute: "coffee", instanceID: "order-123")

        self.date.dateOverride = Date(timeIntervalSince1970: 30)
        editor.apply()

        XCTAssertEqual(1, out?.count)
        XCTAssertEqual(AttributeUpdateType.remove, out?.first?.type)
        XCTAssertEqual("coffee#order-123", out?.first?.attribute)
    }

    func testJSONAttributeValidation() throws {
        let editor = AttributesEditor(date: self.date) { _ in }

        // Empty JSON
        XCTAssertThrowsError(try editor.set(
            json: [:],
            attribute: "test",
            instanceID: "id"
        ))

        // JSON contains reserved key
        let badPayload: [String: AirshipJSON] = [
            "exp": .number(100)
        ]
        XCTAssertThrowsError(try editor.set(
            json: badPayload,
            attribute: "test",
            instanceID: "id"
        ))

        // Attribute or instanceID validation
        let payload: [String: AirshipJSON] = ["k": .string("v")]
        XCTAssertThrowsError(try editor.set(
            json: payload,
            attribute: "has#pound",
            instanceID: "id"
        ))

        XCTAssertThrowsError(try editor.set(
            json: payload,
            attribute: "",
            instanceID: "id"
        ))

        XCTAssertThrowsError(try editor.set(
            json: payload,
            attribute: "valid",
            instanceID: "bad#id"
        ))

        XCTAssertThrowsError(try editor.set(
            json: payload,
            attribute: "valid",
            instanceID: ""
        ))
    }

}
