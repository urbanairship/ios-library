/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockConversation : ConversationProtocol {
    var isConnected: Bool = false
    var delegate: ConversationDelegate?

    var lastMessageSent : String?
    var messages : [ChatMessage]?
    

    func send(_ text: String) {
        self.lastMessageSent = text
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessage>) -> ()) {
        completionHandler(self.messages ?? [])
    }
}
