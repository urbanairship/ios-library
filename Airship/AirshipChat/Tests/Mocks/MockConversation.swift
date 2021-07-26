/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockConversation : InternalConversationProtocol {
    var enabled: Bool = true
    var isConnected = false
    var delegate: ConversationDelegate?
    var clearDataCalled = false
    var routing: ChatRouting? = ChatRouting(agent: "")

    var lastMessageSent : String?
    var lastAttachmentSent : URL?

    var messages : [ChatMessage]?
    var refreshed = false
   
    func connect() {}
    
    func refresh() {
        self.refreshed = true
    }
    
    func clearData() {
        self.clearDataCalled = true;
    }

    func sendMessage(_ text: String) {
        self.sendMessage(text, attachment: nil)
    }

    func sendMessage(_ text: String?, attachment: URL?) {
        self.lastMessageSent = text
        self.lastAttachmentSent = attachment
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessage>) -> ()) {
        completionHandler(self.messages ?? [])
    }
}
