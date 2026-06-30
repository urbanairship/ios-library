/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@Suite struct AttributeEditorTest {

    let date: UATestDate

    init() {
        self.date = UATestDate()
    }

    @Test
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

        #expect(2 == out?.count)

        let foo = out?.first { $0.attribute == "foo" }
        let bar = out?.first { $0.attribute == "bar" }

        #expect(AttributeUpdateType.remove == foo?.type)
        #expect(applyDate == foo?.date)
        #expect(foo?.jsonValue?.unWrap() == nil)

        #expect(AttributeUpdateType.set == bar?.type)
        #expect("neat" == bar?.jsonValue?.unWrap() as? String)
        #expect(applyDate == foo?.date)
    }

    @Test
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

        #expect(AttributeUpdateType.set == attribute?.type)
        #expect(applyDate == attribute?.date)
        #expect(
            "1970-01-01T02:46:40Z" == attribute?.jsonValue?.unWrap() as! String
        )
    }

    @Test
    func testEditorNoAttributes() throws {
        var out: [AttributeUpdate]?

        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        editor.apply()

        #expect(0 == out?.count)
    }

    @Test
    func testEditorEmptyString() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }
        editor.set(string: "", attribute: "cool")
        editor.set(string: "cool", attribute: "")
        editor.apply()

        #expect(0 == out?.count)
    }

    @Test
    func testSetJSONAttributeNoExpiration() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        let payload: [String: AirshipJSON] = [
            "flavor": "vanilla",
            "rating": 5.0,
            "available": true,
        ]

        try editor.set(
            json: payload,
            attribute: "icecream",
            instanceID: "store-123"
        )

        let now = Date(timeIntervalSince1970: 10)
        self.date.dateOverride = now
        editor.apply()

        #expect(1 == out?.count)
        guard let first = out?.first else {
            Issue.record("missing update")
            return
        }

        #expect(AttributeUpdateType.set == first.type)
        #expect("icecream#store-123" == first.attribute)
        #expect(now == first.date)

        let unwrapped = first.jsonValue?.unWrap() as? [String: AnyHashable]
        #expect(3 == unwrapped?.count)
        #expect("vanilla" == unwrapped?["flavor"] as? String)
        #expect(5.0 == unwrapped?["rating"] as? Double)
        #expect(true == unwrapped?["available"] as? Bool)
        #expect(unwrapped?["exp"] == nil, "Unexpected expiry key present")
    }

    @Test
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
            Issue.record("Missing update")
            return
        }

        #expect("coffee#order-123" == update.attribute)
        #expect(AttributeUpdateType.set == update.type)

        let dict = update.jsonValue?.unWrap() as? [String: AnyHashable]
        #expect("large" == dict?["size"] as? String)

        if let exp = dict?["exp"] as? Double {
            #expect(abs(expiration.timeIntervalSince1970 - exp) <= 0.001)
        } else {
            Issue.record("Missing expiration key in payload")
        }
    }

    @Test
    func testRemoveJSONAttribute() throws {
        var out: [AttributeUpdate]?
        let editor = AttributesEditor(date: self.date) { updates in
            out = updates
        }

        try editor.remove(attribute: "coffee", instanceID: "order-123")

        self.date.dateOverride = Date(timeIntervalSince1970: 30)
        editor.apply()

        #expect(1 == out?.count)
        #expect(AttributeUpdateType.remove == out?.first?.type)
        #expect("coffee#order-123" == out?.first?.attribute)
    }

    @Test
    func testJSONAttributeValidation() throws {
        let editor = AttributesEditor(date: self.date) { _ in }

        // Empty JSON
        #expect(throws: (any Error).self) {
            try editor.set(
                json: [:],
                attribute: "test",
                instanceID: "id"
            )
        }

        // JSON contains reserved key
        let badPayload: [String: AirshipJSON] = [
            "exp": 100
        ]
        #expect(throws: (any Error).self) {
            try editor.set(
                json: badPayload,
                attribute: "test",
                instanceID: "id"
            )
        }

        // Attribute or instanceID validation
        let payload: [String: AirshipJSON] = ["k": .string("v")]
        #expect(throws: (any Error).self) {
            try editor.set(
                json: payload,
                attribute: "has#pound",
                instanceID: "id"
            )
        }

        #expect(throws: (any Error).self) {
            try editor.set(
                json: payload,
                attribute: "",
                instanceID: "id"
            )
        }

        #expect(throws: (any Error).self) {
            try editor.set(
                json: payload,
                attribute: "valid",
                instanceID: "bad#id"
            )
        }

        #expect(throws: (any Error).self) {
            try editor.set(
                json: payload,
                attribute: "valid",
                instanceID: ""
            )
        }
    }

}
