/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class AirshipJSONTest: XCTestCase {
    func testWrapPrimitives() throws {
        XCTAssertEqual(.number(100.0), try AirshipJSON.wrap(100.0))
        XCTAssertEqual(.number(99.0), try AirshipJSON.wrap(99))
        XCTAssertEqual(.number(33.0), try AirshipJSON.wrap(UInt(33)))
        XCTAssertEqual(.number(1), try AirshipJSON.wrap(1))
        XCTAssertEqual(.number(0), try AirshipJSON.wrap(0))

        XCTAssertEqual(.string("hello"), try AirshipJSON.wrap("hello"))
        XCTAssertEqual(.bool(true), try AirshipJSON.wrap(true))
        XCTAssertEqual(.bool(false), try AirshipJSON.wrap(false))
        XCTAssertEqual(.null, try AirshipJSON.wrap(nil))
    }

    func testWrapNSNumber() throws {
        XCTAssertEqual(.number(100.0), try AirshipJSON.wrap(NSNumber(100)))
        XCTAssertEqual(.number(99.0), try AirshipJSON.wrap(NSNumber(99.0)))
        XCTAssertEqual(.number(33.0), try AirshipJSON.wrap(NSNumber(33.0)))
        XCTAssertEqual(.number(1), try AirshipJSON.wrap(NSNumber(1)))
        XCTAssertEqual(.number(0), try AirshipJSON.wrap(NSNumber(0)))
        XCTAssertEqual(.bool(true), try AirshipJSON.wrap(NSNumber(true)))
        XCTAssertEqual(.bool(false), try AirshipJSON.wrap(NSNumber(false)))
    }

    func testWrapArray() throws {
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
            .string("hello"),
            .number(100.0),
            .array(
                [
                    .string("foo"),
                    .object(["cool": .string("story")]),
                ]
            ),
            .object(["neat": .string("object")]),
            .null,
            .bool(true),
        ]

        XCTAssertEqual(.array(expected), try AirshipJSON.wrap(array))
    }

    func testWrapObject() throws {
        let object: [String: Any?] = [
            "string": "hello",
            "number": 100.0,
            "array": ["cool", "story"],
            "null": nil,
            "boolean": true,
            "object": ["neat": "object"],
        ]

        let expected: [String: AirshipJSON] = [
            "string": .string("hello"),
            "number": .number(100.0),
            "array": .array([.string("cool"), .string("story")]),
            "null": .null,
            "boolean": .bool(true),
            "object": .object(["neat": .string("object")]),
        ]

        XCTAssertEqual(.object(expected), try AirshipJSON.wrap(object))
    }

    func testWrapInvalid() throws {
        XCTAssertThrowsError(try AirshipJSON.wrap(InvalidJSON()))
    }

    fileprivate struct InvalidJSON {
    }
}
