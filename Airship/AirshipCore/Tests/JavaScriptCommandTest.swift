/* Copyright Airship and Contributors */

import XCTest
import AirshipCore

final class JavaScriptCommandTest: XCTestCase {

    func testCommandForURL() {
            let URL = URL(string: "uairship://whatever/argument-one/argument-two?foo=bar&foo=barbar&foo")!
            let command = JavaScriptCommand(url: URL)

            XCTAssertNotNil(command, "data should be non-nil")
            XCTAssertEqual(command.arguments.count, 2, "data should have two arguments")
            XCTAssertEqual(command.arguments.first, "argument-one", "first arg should be 'argument-one'")
            XCTAssertEqual(command.arguments[1], "argument-two", "second arg should be 'argument-two'")

            let expectedValues = ["bar", "barbar", ""]
            XCTAssertEqual(command.options["foo"], expectedValues, "key 'foo' should have values 'bar', 'barbar', and ''")
        }

        func testCommandForURLSlashBeforeArgs() {
            let URL = URL(string: "uairship://whatever/?foo=bar")!
            let command = JavaScriptCommand(url: URL)
            XCTAssertNotNil(command, "data should be non-nil")
            XCTAssertEqual(command.arguments.count, 0, "data should have no arguments")
            XCTAssertEqual(command.options["foo"], ["bar"], "key 'foo' should have values 'bar'")
        }

        func testCallDataForURLEncodedArguments() {
            let URL = URL(string: "uairship://run-action-cb/%5Eu/%22https%3A%2F%2Fdocs.urbanairship.com%2Fengage%2Frich-content-editor%2F%23rich-content-image%22/ua-cb-2?query%20argument=%5E")!
            let command = JavaScriptCommand(url: URL)

            XCTAssertEqual(command.arguments.count, 3)
            XCTAssertEqual(command.arguments[0], "^u")
            XCTAssertEqual(command.arguments[1], "\"https://docs.urbanairship.com/engage/rich-content-editor/#rich-content-image\"")
            XCTAssertEqual(command.arguments[2], "ua-cb-2")
            XCTAssertEqual(command.options["query argument"], ["^"])
        }

}
