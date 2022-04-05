/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class SubscriptionListActionTests: XCTestCase {
    var action: SubscriptionListAction!
    var channel: TestChannel!
    var contact: TestContact!
    override func setUp() {
        self.channel = TestChannel()
        self.channel.subscriptionListEditor = SubscriptionListEditor(completionHandler: { updates in })
        self.contact = TestContact()
        self.contact.subscriptionListEditor = ScopedSubscriptionListEditor(date: AirshipDate(), completionHandler: { updates in })
        self.action = SubscriptionListAction(channel: {return self.channel}, contact: {return self.contact})
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation,
            Situation.foregroundPush,
            Situation.backgroundInteractiveButton
        ]

        let rejectedSituations = [
            Situation.backgroundPush
        ]

        validSituations.forEach { (situation) in
            let args = ActionArguments(value: [[:]], with: situation)
         
            XCTAssertTrue(self.action.acceptsArguments(args))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: nil, with: situation)
         
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }

    func testPerformWithoutArgs() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: nil, with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testPerformWithValidChannelPayload() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let edits = [["type": "channel",
            "action": "subscribe",
            "list": "456"], ["type": "channel",
                     "action": "unsubscribe",
                     "list": "4567"]]
        let args = ActionArguments(value: ["edits":edits], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
  
    func testPerformWithInvalidChannelPayload() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let edits = [["type": "channel",
            "action": "subscribe"], ["type": "channel",
                     "action": "unsubscribe"]]
        let args = ActionArguments(value: ["edits":edits], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPerformWithValidContactPayload() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let edits = [["type": "contact",
                      "action": "subscribe","list": "456", "scope":"app"], ["type": "contact",
                                                                            "action": "unsubscribe", "list": "4567", "scope":"app"]]
        let args = ActionArguments(value: ["edits":edits], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
  
    func testPerformWithInvalidContactPayload() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let edits = [["type": "contact",
                      "action": "subscribe","list": "456", "scope":"apps"], ["type": "contact",
                                                                            "action": "unsubscribe", "list": "4567", "scope":"apps"]]
        let args = ActionArguments(value: ["edits":edits], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
