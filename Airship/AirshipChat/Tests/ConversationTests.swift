/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore


class ConversationTests: XCTestCase {
    var mockChatConnection : MockChatConnection!
    var mockAPIClient : MockChatAPIClient!
    var mockChannel: MockChannel!
    var mockStateTracker: MockAppStateTracker!
    var mockConfig: MockChatConfig!
    var notificationCenter: NotificationCenter!
    var mockChatDAO: MockChatDAO!

    var conversation : Conversation!
    override func setUp() {
        self.mockChatConnection = MockChatConnection()
        self.mockChannel = MockChannel()
        self.mockStateTracker = MockAppStateTracker()
        self.mockAPIClient = MockChatAPIClient()

        self.notificationCenter = NotificationCenter()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)

        self.mockConfig = MockChatConfig(appKey: "someAppKey",
                                         chatURL: "https://test",
                                         chatWebSocketURL: "wss:test")
        self.mockChatDAO = MockChatDAO()

        self.conversation = Conversation(dataStore: dataStore,
                                         chatConfig: self.mockConfig,
                                         channel: self.mockChannel,
                                         client: self.mockAPIClient,
                                         chatConnection: self.mockChatConnection,
                                         chatDAO: self.mockChatDAO,
                                         appStateTracker: self.mockStateTracker,
                                         dispatcher: MockDispatcher(),
                                         notificationCenter: self.notificationCenter)
    }

    func testRemoteConfigUpdated() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        self.conversation.connect()

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-uvp", self.mockChatConnection.lastUVP)

        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-other-uvp"), nil)
        self.notificationCenter.post(name: RuntimeConfig.configUpdatedEvent, object: nil)

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-other-uvp", self.mockChatConnection.lastUVP)

    }
    func testConnectingShouldCreateUVP() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        self.conversation.connect()

        XCTAssertEqual("channel id", self.mockAPIClient.lastChannel)

        self.mockAPIClient.lastChannel = nil

        background()
        self.conversation.connect()
        XCTAssertNil(self.mockAPIClient.lastChannel)
    }

    func testConnectRequestsConvo() throws {
        self.connect()
        XCTAssertTrue(self.mockChatConnection.requestedConversation)
    }

    func testForegroundConnects() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        
        foreground()

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-uvp", self.mockChatConnection.lastUVP)
    }

    func testSendMessageAfterSync() throws {
        self.conversation.routing = ChatRouting(agent: "person")

        self.mockStateTracker.mockState = ApplicationState.active
        self.connect()

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.conversation.sendMessage("hello!")

        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
        XCTAssertNotNil(self.mockChatConnection.lastSendMessage?.0)
        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.2)
        XCTAssertEqual(ChatMessageDirection.outgoing,  self.mockChatConnection.lastSendMessage?.3)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.4)
        XCTAssertEqual(self.conversation.routing, self.mockChatConnection.lastSendMessage?.5)
    }

    func testSendMessageBeforeSync() throws {
        self.conversation.routing = ChatRouting(agent: "person")

        self.connect()

        self.conversation.sendMessage("hello!")
        XCTAssertNil(self.mockChatConnection.lastSendMessage)

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertNotNil(self.mockChatConnection.lastSendMessage?.0)
        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.2)
        XCTAssertEqual(ChatMessageDirection.outgoing,  self.mockChatConnection.lastSendMessage?.3)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.4)
        XCTAssertEqual(self.conversation.routing, self.mockChatConnection.lastSendMessage?.5)
    }
    
    func testSendIncomingBeforeSync() throws {
        self.conversation.routing = ChatRouting(agent: "person")

        self.connect()
        
        self.conversation.routing = ChatRouting(agent: "person")

        let date = Date()
        let incoming = [ChatIncomingMessage(message: "hi", url: nil, date:date, messageID: "some-message-id")]
        self.conversation.addIncoming(incoming)
        
        XCTAssertNil(self.mockChatConnection.lastSendMessage)

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertEqual("some-message-id", self.mockChatConnection.lastSendMessage?.0)
        XCTAssertEqual("hi", self.mockChatConnection.lastSendMessage?.1)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.2)
        XCTAssertEqual(ChatMessageDirection.incoming,  self.mockChatConnection.lastSendMessage?.3)
        XCTAssertEqual(date, self.mockChatConnection.lastSendMessage?.4)
        XCTAssertEqual(self.conversation.routing, self.mockChatConnection.lastSendMessage?.5)
    }
    
    func testSendIncomingAfterSync() throws {
        self.conversation.routing = ChatRouting(agent: "person")

        self.mockStateTracker.mockState = ApplicationState.active
        self.connect()

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        
        let date = Date()
        let incoming = [ChatIncomingMessage(message: "hi", url: nil, date:date, messageID: "some-message-id")]
        self.conversation.addIncoming(incoming)
        
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertEqual("some-message-id", self.mockChatConnection.lastSendMessage?.0)
        XCTAssertEqual("hi", self.mockChatConnection.lastSendMessage?.1)
        XCTAssertNil(self.mockChatConnection.lastSendMessage?.2)
        XCTAssertEqual(ChatMessageDirection.incoming,  self.mockChatConnection.lastSendMessage?.3)
        XCTAssertEqual(date, self.mockChatConnection.lastSendMessage?.4)
        XCTAssertEqual(self.conversation.routing, self.mockChatConnection.lastSendMessage?.5)
    }

    func testSendMessageNilTextAndAttachment() throws {
        self.connect()
        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.conversation.sendMessage(nil, attachment: nil)
        XCTAssertNil(self.mockChatConnection.lastSendMessage)
    }

    func testSendMessageBeforeConnect() throws {
        self.conversation.sendMessage("hello!")
        XCTAssertNil(self.mockChatConnection.lastSendMessage)

        self.connect()
        XCTAssertNil(self.mockChatConnection.lastSendMessage)

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
    }

    
    func testBackgroundClosesConnectionIfPendingSent() throws  {
        self.connect()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

        self.background()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

        self.conversation.connect()

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.background()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testBackgroundPendingMessages() throws  {
        self.connect()
        self.conversation.sendMessage("hello!")

        self.background()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)


        let message = ChatResponse.Message(messageID: 100, createdOn: Date(), direction: 0, text: "hello!", attachment: nil, requestID: self.mockChatConnection.lastSendMessage?.0)
        let messageReceivedPayload = ChatResponse.SentMessageResponsePayload(message: message)
        let messageReceivedResponse = ChatResponse(type: "message_received", payload: messageReceivedPayload)
        self.mockChatConnection.delegate?.onChatResponse(messageReceivedResponse)

        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testRefershInBackground() throws  {
        self.connect()
        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.background()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)

        self.conversation.refresh()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testConnectionStatus() throws {
        connect()

        XCTAssertFalse(self.conversation.isConnected)

        self.mockChatConnection.delegate?.onOpen()
        XCTAssertTrue(self.conversation.isConnected)

        self.mockChatConnection.delegate?.onClose(.error)
        XCTAssertFalse(self.conversation.isConnected)
    }

    func testConnectWhileDisabled() throws {
        self.conversation.enabled = false
        connect()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
        XCTAssertNil(self.mockAPIClient.lastChannel)
    }

    func testDisableWhileConnected() throws {
        connect()
        self.conversation.enabled = false
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testConnectWhenDisabled() throws {
        self.mockConfig.chatURL = nil
        self.mockConfig.chatWebSocketURL = nil
        connect()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
        XCTAssertNil(self.mockAPIClient.lastChannel)
    }

    func testSendWhileDisabled() throws {
        self.conversation.enabled = false
        self.conversation.sendMessage("sup")

        let expectation = XCTestExpectation(description: "check")
        self.mockChatDAO.fetchPending { (pending) in
            XCTAssertTrue(pending.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }


    func testClearDataWipesUVP() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        self.conversation.connect()

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-uvp", self.mockChatConnection.lastUVP)

        self.conversation.clearData()

        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-other-uvp"), nil)
        self.conversation.connect()

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-other-uvp", self.mockChatConnection.lastUVP)
    }

    func testClearDataClosesConnection() throws {
        connect()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

        self.conversation.clearData()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testClearDataWipesMessages() throws {
        self.conversation.sendMessage("sup")

        var expectation = XCTestExpectation(description: "check")
        self.mockChatDAO.fetchPending { (pending) in
            XCTAssertFalse(pending.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        self.conversation.clearData()

        expectation = XCTestExpectation(description: "check")
        self.mockChatDAO.fetchPending { (pending) in
            XCTAssertTrue(pending.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchMessagesPending() throws {
        let date = Date()
        let incoming = [ChatIncomingMessage(message: "incoming", url: nil, date:date, messageID: "some-message-id")]
        self.conversation.addIncoming(incoming)
        self.conversation.sendMessage("outgoing")
        
        let expectation = XCTestExpectation(description: "check")
        var result: [ChatMessage]?
        self.conversation.fetchMessages() { (pending) in
            result = pending
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(2, result?.count)
        
        let incomingMessage = result![0]
        XCTAssertEqual("some-message-id", incomingMessage.messageID)
        XCTAssertEqual("incoming", incomingMessage.text)
        XCTAssertEqual(ChatMessageDirection.incoming, incomingMessage.direction)
        XCTAssertEqual(date, incomingMessage.timestamp)
        XCTAssertTrue(incomingMessage.isDelivered) // it lies
        
        let outgoingMessage = result![1]
        XCTAssertNotNil(outgoingMessage.messageID)
        XCTAssertEqual("outgoing", outgoingMessage.text)
        XCTAssertEqual(ChatMessageDirection.outgoing, outgoingMessage.direction)
        XCTAssertNotNil(outgoingMessage.timestamp)
        XCTAssertFalse(outgoingMessage.isDelivered)
    }

    func connect() {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        self.conversation.connect()
    }

    func background() {
        self.mockStateTracker.mockState = ApplicationState.background
        self.notificationCenter.post(name: AppStateTracker.didTransitionToBackground, object: nil)
    }
    
    func foreground() {
        self.mockStateTracker.mockState = ApplicationState.active
        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
    }
}
