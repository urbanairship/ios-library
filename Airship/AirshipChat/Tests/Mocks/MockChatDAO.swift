/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipChat
import AirshipCore

/* Copyright Airship and Contributors */

import Foundation


struct MockChatMessageData : ChatMessageDataProtocol {
    var messageID: Int
    var requestID: String?
    var text: String?
    var createdOn: Date
    var direction: UInt
    var attachment: URL?
}

struct MockPendingChatMessageData : PendingChatMessageDataProtocol {
    var requestID: String
    var text: String?
    var attachment: URL?
    var createdOn: Date
    var direction: UInt
}

class MockChatDAO: ChatDAOProtocol {
    private let dispatcher: UADispatcher
    private var messages = Dictionary<String, ChatMessageDataProtocol>()
    private var pendingMessages = Dictionary<String, PendingChatMessageDataProtocol>()

    init(dispatcher: UADispatcher = MockDispatcher()) {
        self.dispatcher = dispatcher
    }

    func upsertMessage(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?) {
        dispatcher.dispatchAsync {
            self.messages["\(messageID)"] = MockChatMessageData(messageID: messageID,
                                                            requestID: requestID,
                                                            text: text,
                                                            createdOn: createdOn,
                                                            direction: direction,
                                                            attachment: attachment)
        }
    }

    func upsertPending(requestID: String, text: String?, attachment: URL?, createdOn: Date, direction: UInt) {
        dispatcher.dispatchAsync {
            self.pendingMessages[requestID] = MockPendingChatMessageData(requestID: requestID, text: text, attachment: attachment, createdOn: createdOn, direction: direction)
        }
    }

    func removePending(_ requestID: String) {
        dispatcher.dispatchAsync {
            self.pendingMessages.removeValue(forKey: requestID)
        }
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessageDataProtocol>, Array<PendingChatMessageDataProtocol>)->()) {
        dispatcher.dispatchAsync {
            let sortedMessages = self.messages.values.sorted { $0.createdOn <= $1.createdOn }
            let sortedPending = self.pendingMessages.values.sorted { $0.createdOn <= $1.createdOn }
            completionHandler(sortedMessages, sortedPending)
        }
    }

    func fetchPending(completionHandler: @escaping (Array<PendingChatMessageDataProtocol>)->()) {
        dispatcher.dispatchAsync {
            let sortedPending = self.pendingMessages.values.sorted { $0.createdOn <= $1.createdOn }
            completionHandler(sortedPending)
        }
    }

    func hasPendingMessages(completionHandler: @escaping (Bool)->()) {
        dispatcher.dispatchAsync {
            completionHandler(!self.pendingMessages.isEmpty)
        }
    }

    func deleteAll() {
        dispatcher.dispatchAsync {
            self.pendingMessages.removeAll()
            self.messages.removeAll()
        }
    }
}

