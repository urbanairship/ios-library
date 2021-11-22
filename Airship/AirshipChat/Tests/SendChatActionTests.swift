/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class SendChatActionTests: XCTestCase {
    var action: SendChatAction!
    var airshipChat: Chat!

    var mockChatConnection : MockChatConnection!
    var mockAPIClient : MockChatAPIClient!
    var mockChannel: MockChannel!
    var mockStateTracker: MockAppStateTracker!
    var mockConfig: MockChatConfig!
    var notificationCenter: NotificationCenter!
    var mockChatDAO: MockChatDAO!

    var conversation : Conversation!
    var privacyManager : PrivacyManager!

    override func setUp() {
        self.mockChatConnection = MockChatConnection()
        self.mockChannel = MockChannel()
        self.mockStateTracker = MockAppStateTracker()
        self.mockAPIClient = MockChatAPIClient()

        self.notificationCenter = NotificationCenter()
        let dataStore = PreferenceDataStore(appKey: UUID().uuidString)

        self.mockConfig = MockChatConfig(appKey: "someAppKey",
                                         chatURL: "https://test",
                                         chatWebSocketURL: "wss:test")
        self.mockChatDAO = MockChatDAO()

        self.privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        
        self.conversation = Conversation(dataStore: dataStore,
                                         chatConfig: self.mockConfig,
                                         channel: self.mockChannel,
                                         client: self.mockAPIClient,
                                         chatConnection: self.mockChatConnection,
                                         chatDAO: self.mockChatDAO,
                                         appStateTracker: self.mockStateTracker,
                                         dispatcher: MockDispatcher(),
                                         notificationCenter: self.notificationCenter)

        self.airshipChat = Chat(dataStore: dataStore,
                                conversation: conversation,
                                privacyManager:self.privacyManager)


        self.action = SendChatAction() {
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
            let messageArgs = ActionArguments(value: ["message": "neat"], with: situation)
            let routingArgs = ActionArguments(value: ["chat_routing": ChatRouting(agent: "fakeagent")], with: situation)


            XCTAssertTrue(self.action.acceptsArguments(args))
            XCTAssertTrue(self.action.acceptsArguments(messageArgs))
            XCTAssertTrue(self.action.acceptsArguments(routingArgs))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: nil, with: situation)
            let messageArgs = ActionArguments(value: ["message": "neat"], with: situation)
            let routingArgs = ActionArguments(value: ["chat_routing": ChatRouting(agent: "fakeagent")], with: situation)


            XCTAssertFalse(self.action.acceptsArguments(args))
            XCTAssertFalse(self.action.acceptsArguments(messageArgs))
            XCTAssertFalse(self.action.acceptsArguments(routingArgs))
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

    func testPerformWithMessage() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: ["message": "neat"], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPerformWithRouting() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: ["chat_routing": ChatRouting(agent: "fakeagent")], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual("fakeagent", self.conversation.routing?.agent)
    }
    
    func testPerformWithRoutingJson() throws {
        let expectation = XCTestExpectation(description: "Completed")
        let args = ActionArguments(value: ["chat_routing": ["agent": "smith"]], with: .manualInvocation)
        action.perform(with: args) { (result) in
            XCTAssertNil(result.value)
            XCTAssertNil(result.error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual("smith", self.conversation.routing?.agent)
    }
}
