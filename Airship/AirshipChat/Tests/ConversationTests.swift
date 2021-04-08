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

        self.conversation = Conversation(dataStore: dataStore,
                                         appKey: "app key",
                                         channel: self.mockChannel,
                                         client: self.mockAPIClient,
                                         chatConnection: self.mockChatConnection,
                                         chatDAO: self.chatDAO,
                                         appStateTracker: self.mockStateTracker,
                                         dispatcher: ImmediateDispatcher(),
                                         notificationCenter: self.notificationCenter)
    }

    func testConnectingShouldCreateUVP() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)
        foreground()

        XCTAssertEqual("channel id", self.mockAPIClient.lastChannel)
        XCTAssertEqual("app key", self.mockAPIClient.lastAppKey)

        self.mockAPIClient.lastChannel = nil
        self.mockAPIClient.lastAppKey = nil

        background()
        foreground()
        XCTAssertNil(self.mockAPIClient.lastChannel)
        XCTAssertNil(self.mockAPIClient.lastAppKey)
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

    func testBackgroundDisconnects() throws {
        self.mockChannel.identifier = "channel id"
        self.mockAPIClient.result = (UVPResponse(status: 200, uvp: "some-uvp"), nil)

        foreground()
        background()
        XCTAssertFalse(self.mockChatConnection.isOpenOrOpening)
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

    func testBackgroundClosesConnection() throws  {
        self.connect()
        XCTAssertTrue(self.mockChatConnection.isOpenOrOpening)

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

    func testConnectionStatus() throws {
        connect()

        XCTAssertFalse(self.conversation.isConnected)

        self.mockChatConnection.delegate?.onOpen()
        XCTAssertTrue(self.conversation.isConnected)

        self.mockChatConnection.delegate?.onClose(.error)
        XCTAssertFalse(self.conversation.isConnected)
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
