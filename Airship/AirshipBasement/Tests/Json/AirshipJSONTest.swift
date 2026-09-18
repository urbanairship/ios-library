/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipBasement

struct AirshipJSONTest {
    @Test
    func wrapPrimitives() throws {
        #expect(try AirshipJSON.wrap(100.0) == .number(100.0))
        #expect(try AirshipJSON.wrap(99) == .number(99.0))
        #expect(try AirshipJSON.wrap(UInt(33)) == .number(33.0))
        #expect(try AirshipJSON.wrap(1) == .number(1))
        #expect(try AirshipJSON.wrap(0) == .number(0))

        #expect(try AirshipJSON.wrap("hello") == .string("hello"))
        #expect(try AirshipJSON.wrap(true) == .bool(true))
        #expect(try AirshipJSON.wrap(false) == .bool(false))
        #expect(try AirshipJSON.wrap(nil) == .null)
    }

    @Test
    func wrapNSNumber() throws {
        #expect(try AirshipJSON.wrap(NSNumber(100)) == .number(100.0))
        #expect(try AirshipJSON.wrap(NSNumber(99.0)) == .number(99.0))
        #expect(try AirshipJSON.wrap(NSNumber(33.0)) == .number(33.0))
        #expect(try AirshipJSON.wrap(NSNumber(1)) == .number(1))
        #expect(try AirshipJSON.wrap(NSNumber(0)) == .number(0))
        #expect(try AirshipJSON.wrap(NSNumber(true)) == .bool(true))
        #expect(try AirshipJSON.wrap(NSNumber(false)) == .bool(false))
    }

    @Test
    func wrapArray() throws {
        let array: [Any?] = [
            "hello",
            100,
            [
                "foo",
                ["cool": "story"],
            ] as [Any],
            ["neat": "object"],
            nil,
            true,
        ]

        let expected: [AirshipJSON] = [
            "hello",
            100.0,
            ["foo", ["cool": "story"], ],
            ["neat": "object"],
            nil,
            true,
        ]

        #expect(try AirshipJSON.wrap(array) == .array(expected))
    }

    @Test
    func wrapObject() throws {
        let object: [String: Any?] = [
            "string": "hello",
            "number": 100.0,
            "array": ["cool", "story"],
            "null": nil,
            "boolean": true,
            "object": ["neat": "object"],
        ]

        let expected: [String: AirshipJSON] = [
            "string": "hello",
            "number": 100.0,
            "array": ["cool", "story"],
            "null": nil,
            "boolean": true,
            "object": ["neat": "object"],
        ]

        #expect(try AirshipJSON.wrap(object) == .object(expected))
    }

    @Test
    func wrapNSNull() throws {
        #expect(try AirshipJSON.wrap(NSNull()) == .null)
    }

    @Test
    func wrapObjCContainersWithNSNull() throws {
        let object = NSMutableDictionary()
        object.setObject(NSNull(), forKey: "null" as NSString)
        object.setObject("hello" as NSString, forKey: "string" as NSString)
        object.setObject(
            NSArray(array: [NSNull(), "story"]),
            forKey: "array" as NSString
        )

        let expected: [String: AirshipJSON] = [
            "null": nil,
            "string": "hello",
            "array": [nil, "story"],
        ]

        #expect(try AirshipJSON.wrap(object) == .object(expected))
    }

    @Test
    func wrapInvalid() throws {
        #expect(throws: (any Error).self) {
            try AirshipJSON.wrap(InvalidJSON())
        }
    }

    fileprivate struct InvalidJSON {
    }
}
