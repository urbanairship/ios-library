/* Copyright Airship and Contributors */

import Testing
import Foundation
import AirshipCore

@Suite
struct JavaScriptCommandTest {

    @Test
    func testCommandForURL() {
        let URL = URL(string: "uairship://whatever/argument-one/argument-two?foo=bar&foo=barbar&foo")!
        let command = JavaScriptCommand(url: URL)

        #expect(command.arguments.count == 2, "data should have two arguments")
        #expect(command.arguments.first == "argument-one", "first arg should be 'argument-one'")
        #expect(command.arguments[1] == "argument-two", "second arg should be 'argument-two'")

        let expectedValues = ["bar", "barbar", ""]
        #expect(command.options["foo"] == expectedValues, "key 'foo' should have values 'bar', 'barbar', and ''")
    }

    @Test
    func testCommandForURLSlashBeforeArgs() {
        let URL = URL(string: "uairship://whatever/?foo=bar")!
        let command = JavaScriptCommand(url: URL)
        #expect(command.arguments.count == 0, "data should have no arguments")
        #expect(command.options["foo"] == ["bar"], "key 'foo' should have values 'bar'")
    }

    @Test
    func testCallDataForURLEncodedArguments() {
        let URL = URL(string: "uairship://run-action-cb/%5Eu/%22https%3A%2F%2Fdocs.urbanairship.com%2Fengage%2Frich-content-editor%2F%23rich-content-image%22/ua-cb-2?query%20argument=%5E")!
        let command = JavaScriptCommand(url: URL)

        #expect(command.arguments.count == 3)
        #expect(command.arguments[0] == "^u")
        #expect(command.arguments[1] == "\"https://docs.urbanairship.com/engage/rich-content-editor/#rich-content-image\"")
        #expect(command.arguments[2] == "ua-cb-2")
        #expect(command.options["query argument"] == ["^"])
    }

}
