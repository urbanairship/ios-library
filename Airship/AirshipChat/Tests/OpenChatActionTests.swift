/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class OpenChatActionTests: XCTestCase {
    var action: OpenChatAction!
    var airshipChat: AirshipChat!
    var mockConversation: MockConversation!
    var mockOpenDelegate: MockAirshipChatOpenDelegate!

    override func setUp() {
        let mockConversation = MockConversation()
        let dataStore = UAPreferenceDataStore(keyPrefix: UUID().uuidString)

        self.airshipChat = AirshipChat(dataStore: dataStore,
                                       conversation: mockConversation)

        self.mockOpenDelegate = MockAirshipChatOpenDelegate()
        self.airshipChat.openChatDelegate = self.mockOpenDelegate

        self.action = OpenChatAction() {
            return self.airshipChat
        }
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            UASituation.foregroundInteractiveButton,
            UASituation.launchedFromPush,
            UASituation.manualInvocation,
            UASituation.webViewInvocation,
            UASituation.automation
        ]

        let rejectedSituations = [
            UASituation.backgroundPush,
            UASituation.foregroundPush,
            UASituation.backgroundInteractiveButton
        ]

        validSituations.forEach { (situation) in
            let args = UAActionArguments(value: nil, with: situation)
            let messageArgs = UAActionArguments(value: ["chat_input": "neat"], with: situation)

            XCTAssertTrue(self.action.acceptsArguments(args))
            XCTAssertTrue(self.action.acceptsArguments(messageArgs))
        }

        rejectedSituations.forEach { (situation) in
            let args = UAActionArguments(value: nil, with: situation)
            let messageArgs = UAActionArguments(value: ["chat_input": "neat"], with: situation)

            XCTAssertFalse(self.action.acceptsArguments(args))
            XCTAssertFalse(self.action.acceptsArguments(messageArgs))
        }
    }

    func testPerform() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = UAActionArguments(value: nil, with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.mockOpenDelegate.openCalled)
        XCTAssertNil(self.mockOpenDelegate.lastOpenMessage)

    }

    func testPerformWithMessage() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = UAActionArguments(value: ["chat_input": "neat"], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.mockOpenDelegate.openCalled)
        XCTAssertEqual("neat", self.mockOpenDelegate.lastOpenMessage)
    }
}
