/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@Suite struct AccountEventTemplateTest {

    @Test
    func testRegistered() {
        let event = CustomEvent(accountTemplate: .registered)
        #expect("registered_account" == event.eventName)
        #expect("account" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testLoggedIn() {
        let event = CustomEvent(accountTemplate: .loggedIn)
        #expect("logged_in" == event.eventName)
        #expect("account" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testLoggedOut() {
        let event = CustomEvent(accountTemplate: .loggedOut)
        #expect("logged_out" == event.eventName)
        #expect("account" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testProperties() {
        let properties = CustomEvent.AccountProperties(
            category: "some category",
            type: "some type",
            isLTV: true,
            userID: "some user"
        )

        let event = CustomEvent(accountTemplate: .loggedOut, properties: properties)

        let expectedProperties: [String: AirshipJSON] = [
            "user_id": "some user",
            "category": "some category",
            "type": "some type",
            "ltv": true
        ]
        #expect(expectedProperties == event.properties)
    }

}
