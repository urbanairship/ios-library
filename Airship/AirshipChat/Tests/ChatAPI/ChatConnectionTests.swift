/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class ChatConnectionTests: XCTestCase {
    var mockWebSocket: MockWebSocket!
    var mockWebSocketFactory: MockWebSocketFactory!
    var mockDelegate: MockChatConnectionDelegate!
    var mockConfig: MockChatConfig!

    var connection: ChatConnection!

    override func setUp() {
        super.setUp()

        self.mockWebSocket = MockWebSocket()
        self.mockWebSocketFactory = MockWebSocketFactory(socket: self.mockWebSocket)
        self.mockDelegate = MockChatConnectionDelegate()

        self.mockConfig = MockChatConfig(appKey: "app Key",
                                         chatURL: "https://test",
                                         chatWebSocketURL: "wss:test")

        self.connection = ChatConnection(chatConfig: self.mockConfig,
                                         socketFactory: self.mockWebSocketFactory)
        self.connection.delegate = self.mockDelegate
    }

    func testInitiatesClosed() throws {
        XCTAssertFalse(self.connection.isOpenOrOpening)
    }

    func testOpen() throws {
        self.connection.open(uvp: "some-uvp")
        XCTAssertTrue(self.connection.isOpenOrOpening)
        XCTAssertTrue(self.mockWebSocket.isOpen)

        let expectedURL = "wss:test?uvp=some-uvp"
        XCTAssertEqual(expectedURL, self.mockWebSocketFactory.lastURL?.absoluteString)
    }

    func testOpenMissinigURL() throws {
        self.mockConfig.chatWebSocketURL = nil
        self.connection.open(uvp: "some-uvp")
        XCTAssertFalse(self.connection.isOpenOrOpening)
        XCTAssertFalse(self.mockWebSocket.isOpen)
    }

    func testClose() throws {
        self.connection.open(uvp: "some-uvp")
        self.connection.close()
        XCTAssertEqual(CloseReason.manual, self.mockDelegate.lastCloseReason)
    }

    func testRequestConversation() throws {
        self.connection.open(uvp: "some-uvp")
        self.connection.requestConversation()

        XCTAssertNotNil(self.mockWebSocket.lastMessage)
        let object = JSONSerialization.object(with: self.mockWebSocket.lastMessage!) as! [String: String]

        let expected = [
            "action": "fetch_conversation",
            "uvp": "some-uvp"
        ]

        XCTAssertEqual(expected, object)
    }

    func testSend() throws {
        let url = URL(string: "https://neat")
        self.connection.open(uvp: "some-uvp")
        self.connection.sendMessage(requestID: "request!", text: "neat!", attachment: url )

        XCTAssertNotNil(self.mockWebSocket.lastMessage)

        let object = JSONSerialization.object(with: self.mockWebSocket.lastMessage!) as! [String: Any]
        let payload = object["payload"] as! [String : String]

        XCTAssertEqual("some-uvp", object["uvp"] as! String)
        XCTAssertEqual("send_message", object["action"] as! String)
        XCTAssertEqual("request!", payload["request_id"])
        XCTAssertEqual("neat!", payload["text"])
        XCTAssertEqual("https://neat", payload["attachment"])
    }

    func testNewMessageResponse() throws {
        self.connection.open(uvp: "some-uvp")

        let response = """
        {
            "type": "new_message",
            "payload":{
                "success":true,
                "message":{
                    "message_id":1617819415247,
                    "created_on":"2021-04-07T18:16:55Z",
                    "direction":0,
                    "text":"Sup",
                    "attachment": "https://neat",
                    "request_id":"D9DD85A9-F5A1-4E56-9060-4DB4462CFF32"
                }
            }
        }
        """

        self.mockWebSocket.delegate?.onReceive(message: response)

        XCTAssertEqual("new_message", self.mockDelegate.lastResponse?.type)

        let payload = self.mockDelegate.lastResponse?.payload as! ChatResponse.NewMessageResponsePayload
        XCTAssertEqual(1617819415247, payload.message.messageID)
        XCTAssertEqual(UAUtils.parseISO8601Date(from: "2021-04-07T18:16:55Z"), payload.message.createdOn)
        XCTAssertEqual("D9DD85A9-F5A1-4E56-9060-4DB4462CFF32", payload.message.requestID)
        XCTAssertEqual(0, payload.message.direction)
        XCTAssertEqual("Sup", payload.message.text)
        XCTAssertEqual(URL(string: "https://neat"), payload.message.attachment)

    }

    func testReceivedMessageResponse() throws {
        self.connection.open(uvp: "some-uvp")

        let response = """
        {
            "type": "message_received",
            "payload":{
                "success":true,
                "message":{
                    "message_id":1617819415247,
                    "created_on":"2021-04-07T18:16:55Z",
                    "direction":0,
                    "text":"Sup",
                    "attachment":null,
                    "request_id":"D9DD85A9-F5A1-4E56-9060-4DB4462CFF32"
                }
            }
        }
        """

        self.mockWebSocket.delegate?.onReceive(message: response)

        XCTAssertEqual("message_received", self.mockDelegate.lastResponse?.type)

        let payload = self.mockDelegate.lastResponse?.payload as! ChatResponse.SentMessageResponsePayload
        XCTAssertEqual(1617819415247, payload.message.messageID)
        XCTAssertEqual(UAUtils.parseISO8601Date(from: "2021-04-07T18:16:55Z"), payload.message.createdOn)
        XCTAssertEqual("D9DD85A9-F5A1-4E56-9060-4DB4462CFF32", payload.message.requestID)
        XCTAssertEqual(0, payload.message.direction)
        XCTAssertEqual("Sup", payload.message.text)
    }

    func testConversationResponse() throws {
        self.connection.open(uvp: "some-uvp")

        let response = """
        {
            "type":"conversation_loaded",
            "payload":{
                "messages":[
                {
                "message_id":1617642327507,
                "created_on":"2021-04-05T17:05:27Z",
                "direction":0,
                "text":"Hello",
                "attachment":null,
                "request_id":"D9DD85A9-F5A1-4E56-9060-4DB4462CFF32"
                },
                {
                "message_id":1617642338659,
                "created_on":"2021-04-05T17:05:38Z",
                "direction":1,
                "text":"Hi!",
                "attachment":null,
                "request_id":null
                },
                ]
            }
        }
        """

        self.mockWebSocket.delegate?.onReceive(message: response)

        XCTAssertEqual("conversation_loaded", self.mockDelegate.lastResponse?.type)

        let payload = self.mockDelegate.lastResponse?.payload as! ChatResponse.ConversationLoadedResponsePayload
        XCTAssertEqual(1617642327507, payload.messages![0].messageID)
        XCTAssertEqual(UAUtils.parseISO8601Date(from: "2021-04-05T17:05:27Z"), payload.messages![0].createdOn)
        XCTAssertEqual("D9DD85A9-F5A1-4E56-9060-4DB4462CFF32", payload.messages![0].requestID)
        XCTAssertEqual(0, payload.messages![0].direction)
        XCTAssertEqual("Hello", payload.messages![0].text)

        XCTAssertEqual(1617642338659, payload.messages![1].messageID)
        XCTAssertEqual(UAUtils.parseISO8601Date(from: "2021-04-05T17:05:38Z"), payload.messages![1].createdOn)
        XCTAssertNil(payload.messages![1].requestID)
        XCTAssertEqual(1, payload.messages![1].direction)
        XCTAssertEqual("Hi!", payload.messages![1].text)
    }

    func testOnOpen() throws {
        self.connection.open(uvp: "some-uvp")

        XCTAssertFalse(self.mockDelegate.isOpen)
        self.mockWebSocket.delegate?.onOpen()
        XCTAssertTrue(self.mockDelegate.isOpen)
    }

    func testOnError() throws {
        self.connection.open(uvp: "some-uvp")

        let error = NSError(domain: "domain", code: 10, userInfo: nil)
        self.mockWebSocket.delegate?.onError(error: error)

        XCTAssertEqual(CloseReason.error, self.mockDelegate.lastCloseReason)
    }

    func testOnClose() throws {
        self.connection.open(uvp: "some-uvp")
        self.mockWebSocket.delegate?.onClose()
        XCTAssertEqual(CloseReason.server, self.mockDelegate.lastCloseReason)
    }
}

class MockChatConnectionDelegate : ChatConnectionDelegate {
    var isOpen = false
    var lastCloseReason: CloseReason?
    var lastResponse: ChatResponse?

    func onOpen() {
        self.isOpen = true
    }

    func onChatResponse(_ response: ChatResponse) {
        self.lastResponse = response
    }

    func onClose(_ reason: CloseReason) {
        self.isOpen = false
        self.lastCloseReason = reason
    }
}
