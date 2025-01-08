/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AccountEventTemplateTest: XCTestCase {

    func testRegistered() {
        let event = CustomEvent(accountTemplate: .registered)
        XCTAssertEqual("registered_account", event.eventName)
        XCTAssertEqual("account", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [ "ltv": .bool(false) ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testLoggedIn() {
        let event = CustomEvent(accountTemplate: .loggedIn)
        XCTAssertEqual("logged_in", event.eventName)
        XCTAssertEqual("account", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [ "ltv": .bool(false) ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testLoggedOut() {
        let event = CustomEvent(accountTemplate: .loggedOut)
        XCTAssertEqual("logged_out", event.eventName)
        XCTAssertEqual("account", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [ "ltv": .bool(false) ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testProperties() {
        let properties = CustomEvent.AccountProperties(
            category: "some category",
            type: "some type",
            isLTV: true,
            userID: "some user"
        )

        let event = CustomEvent(accountTemplate: .loggedOut, properties: properties)

        let expectedProperties: [String: AirshipJSON] = [
            "user_id": .string("some user"),
            "category": .string("some category"),
            "type": .string("some type"),
            "ltv": .bool(true)
        ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

}
