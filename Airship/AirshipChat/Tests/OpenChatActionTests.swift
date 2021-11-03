/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class OpenChatActionTests: XCTestCase {
    var action: OpenChatAction!
    var airshipChat: Chat!
    var mockConversation: MockConversation!
    var mockOpenDelegate: MockChatOpenDelegate!
    var privacyManager : PrivacyManager!

    override func setUp() {
        self.mockConversation = MockConversation()
        let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)

        self.airshipChat = Chat(dataStore: dataStore,
                                conversation: self.mockConversation,
                                privacyManager:self.privacyManager)

        self.mockOpenDelegate = MockChatOpenDelegate()
        self.airshipChat.openChatDelegate = self.mockOpenDelegate

        self.action = OpenChatAction() {
            return self.airshipChat
        }
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation
        ]

        let rejectedSituations = [
            Situation.backgroundPush,
            Situation.foregroundPush,
            Situation.backgroundInteractiveButton
        ]

        validSituations.forEach { (situation) in
            let args = ActionArguments(value: nil, with: situation)
            let messageArgs = ActionArguments(value: ["chat_input": "neat"], with: situation)

            XCTAssertTrue(self.action.acceptsArguments(args))
            XCTAssertTrue(self.action.acceptsArguments(messageArgs))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: nil, with: situation)
            let messageArgs = ActionArguments(value: ["chat_input": "neat"], with: situation)

            XCTAssertFalse(self.action.acceptsArguments(args))
            XCTAssertFalse(self.action.acceptsArguments(messageArgs))
        }
    }

    func testPerform() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: nil, with: .manualInvocation)
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
        let args = ActionArguments(value: ["chat_input": "neat"], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.mockOpenDelegate.openCalled)
        XCTAssertEqual("neat", self.mockOpenDelegate.lastOpenMessage)
    }
    
    func testPerformPrepopulated() throws {
        let date = Utils.parseISO8601Date(from: "2021-01-01T00:00:00Z")
        let argsData = [
            "prepopulated_messages": [
                [
                    "msg": "hi",
                    "id": "msg-1",
                    "date": "2021-01-01T00:00:00Z"
                ],
                [
                    "msg": "sup",
                    "id": "msg-2",
                    "date": "2021-01-01T00:00:00Z"
                ]
            ]
        ]
        
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: argsData, with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(self.mockOpenDelegate.openCalled)
        let expected = [ ChatIncomingMessage(message: "hi", url: nil, date: date, messageID: "msg-1"),
                         ChatIncomingMessage(message: "sup", url: nil, date: date, messageID: "msg-2") ]
        XCTAssertEqual(expected, self.mockConversation.incoming)
    }
}
