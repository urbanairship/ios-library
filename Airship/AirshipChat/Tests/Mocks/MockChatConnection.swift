/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockChatConnection: ChatConnectionProtocol {
    var isOpenOrOpening = false
    var lastSendMessage: (String, String?, URL?, ChatMessageDirection, Date?, ChatRouting?)?
    var requestedConversation = false
    var delegate: ChatConnectionDelegate?
    var lastUVP: String?

    func close() {
        self.isOpenOrOpening = false
    }

    func open(uvp: String) {
        self.lastUVP = uvp
        self.isOpenOrOpening = true
    }

    func requestConversation() {
        self.requestedConversation = true
    }

    func sendMessage(requestID: String, text: String?, attachment: URL?, direction: ChatMessageDirection, date: Date?, routing: ChatRouting?) {
        self.lastSendMessage = (requestID, text, attachment, direction, date, routing)
    }
}
