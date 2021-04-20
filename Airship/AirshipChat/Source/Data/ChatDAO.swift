/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

import Foundation

/**
 * Chat data access object.
 *
 * In memory for now.
 */
class ChatDAO: ChatDAOProtocol {
    private let dispatcher: UADispatcher
    private var messages = Dictionary<String, ChatMessageData>()
    private var pendingMessages = Dictionary<String, PendingChatMessageData>()

    init(dispatcher: UADispatcher = UADispatcher.serial()) {
        self.dispatcher = dispatcher
    }

    func upsertMessage(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?) {
        dispatcher.dispatchAsync {
            self.messages["\(messageID)"] = ChatMessageData(messageID: messageID,
                                                            requestID: requestID,
                                                            text: text,
                                                            createdOn: createdOn,
                                                            direction: direction,
                                                            attachment: attachment)
        }
    }

    func insertPending(requestID: String, text: String?, attachment: URL?, createdOn: Date) {
        dispatcher.dispatchAsync {
            self.pendingMessages[requestID] = PendingChatMessageData(requestID: requestID, text: text, attachment: attachment, createdOn: createdOn)
        }
    }

    func removePending(_ requestID: String) {
        dispatcher.dispatchAsync {
            self.pendingMessages.removeValue(forKey: requestID)
        }
    }

    func fetchMessages(completionHandler: @escaping (Array<ChatMessageData>, Array<PendingChatMessageData>)->()) {
        dispatcher.dispatchAsync {
            let sortedMessages = self.messages.values.sorted { $0.createdOn <= $1.createdOn }
            let sortedPending = self.pendingMessages.values.sorted { $0.createdOn <= $1.createdOn }
            completionHandler(sortedMessages, sortedPending)
        }
    }

    func fetchPending(completionHandler: @escaping (Array<PendingChatMessageData>)->()) {
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
