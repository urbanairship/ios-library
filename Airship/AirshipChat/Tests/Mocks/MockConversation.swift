/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockConversation : InternalConversationProtocol {
    var enabled: Bool = true
    var isConnected = false
    var delegate: ConversationDelegate?

    var lastMessageSent : String?
    var lastAttachmentSent : URL?

    var messages : [ChatMessage]?
    var refreshed = false

    func refresh() {
        self.refreshed = true
    }
    

    func send(_ text: String) {
        self.send(text, attachment: nil)
    }

    func send(_ text: String?, attachment: URL?) {
        self.lastMessageSent = text
        self.lastAttachmentSent = attachment
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessage>) -> ()) {
        completionHandler(self.messages ?? [])
    }
}
