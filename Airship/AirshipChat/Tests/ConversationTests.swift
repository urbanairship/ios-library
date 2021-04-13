/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class ImmediateDispatcher : UADispatcher {
    override func dispatchSync(_ block: @escaping () -> Void) {
        block()
    }

    override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }

    override func dispatch(after delay: TimeInterval, block: @escaping () -> Void) -> UADisposable {
        block()
        return UADisposable()
    }
}

class ConversationTests: XCTestCase {
    var mockChatConnection : MockChatConnection!
    var mockAPIClient : MockChatAPIClient!
    var mockChannel: MockChannel!
    var mockStateTracker: MockAppStateTracker!
    var mockConfig: MockChatConfig!
    var notificationCenter: NotificationCenter!
    var chatDAO: ChatDAOProtocol!

    var conversation : Conversation!
    override func setUp() {
        self.mockChatConnection = MockChatConnection()
        self.mockChannel = MockChannel()
        self.mockStateTracker = MockAppStateTracker()
        self.mockAPIClient = MockChatAPIClient()

        self.chatDAO = ChatDAO(dispatcher: ImmediateDispatcher())
        self.notificationCenter = NotificationCenter()
        let dataStore = UAPreferenceDataStore(keyPrefix: UUID().uuidString)

        self.mockConfig = MockChatConfig(appKey: "someAppKey",
                                         chatURL: "https://test",
                                         chatWebSocketURL: "wss:test")

        self.conversation = Conversation(dataStore: dataStore,
                                         chatConfig: self.mockConfig,
                                         channel: self.mockChannel,
                                         client: self.mockAPIClient,
                                         chatConnection: self.mockChatConnection,
                                         chatDAO: self.chatDAO,
                                         appStateTracker: self.mockStateTracker,
                                         dispatcher: ImmediateDispatcher(),
                                         notificationCenter: self.notificationCenter)
    }

    func testRemoteConfigUpdated() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        foreground()

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-uvp", self.mockChatConnection.lastUVP)

        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-other-uvp"), nil)
        self.notificationCenter.post(name: NSNotification.Name.UARemoteConfigURLManagerConfigUpdated, object: nil)

        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)
        XCTAssertEqual("some-other-uvp", self.mockChatConnection.lastUVP)

    }
    func testConnectingShouldCreateUVP() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        foreground()

        XCTAssertEqual("channel id", self.mockAPIClient.lastChannel)

        self.mockAPIClient.lastChannel = nil

        background()
        foreground()
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
        self.connect()

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.conversation.send("hello!")

        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
    }

    func testSendMessageBeforeSync() throws {
        self.connect()

        self.conversation.send("hello!")
        XCTAssertNil(self.mockChatConnection.lastSendMessage)

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)

        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)
        XCTAssertEqual("hello!", self.mockChatConnection.lastSendMessage?.1)
    }

    func testSendMessageBeforeConnect() throws {
        self.conversation.send("hello!")
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

        self.foreground()

        let fetchConvoPayload = ChatResponse.ConversationLoadedResponsePayload(messages: nil)
        let fetchConvo = ChatResponse(type: "fetch_conversation", payload: fetchConvoPayload)
        self.mockChatConnection.delegate?.onChatResponse(fetchConvo)

        self.background()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
    }

    func testBackgroundPendingMessages() throws  {
        self.connect()
        self.conversation.send("hello!")

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

    func connect() {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        foreground()
    }

    func foreground() {
        self.mockStateTracker.mockState = UAApplicationState.active
        self.notificationCenter.post(name: NSNotification.Name.UAApplicationDidTransitionToForeground, object: nil)
    }

    func background() {
        self.mockStateTracker.mockState = UAApplicationState.background
        self.notificationCenter.post(name: NSNotification.Name.UAApplicationDidTransitionToBackground, object: nil)
    }
}
