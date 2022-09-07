import Foundation
import AirshipMessageCenter
import AirshipCore
import Combine

extension MessageCenter {

    func markRead(messages: Set<String>) {
        let messages = messages.compactMap {
            self.messageList.message(forID:$0)
        }.filter { $0.unread }

        if !messages.isEmpty {
            MessageCenter.shared.messageList.markMessagesRead(messages)
        }

    }

    func delete(messages: Set<String>) {
        let messages = messages.compactMap {
            self.messageList.message(forID:$0)
        }
        MessageCenter.shared.messageList.markMessagesDeleted(messages)
    }

    var messagePublisher: AnyPublisher<[InboxMessage], Never> {
        NotificationCenter.default.publisher(for: NSNotification.Name.UAInboxMessageListUpdated
        ).map { _ in
            return self.messageList.messages
        }
        .prepend(Just(self.messageList.messages))
        .eraseToAnyPublisher()
    }

    func refreshMessages() async -> Bool {
        return await withCheckedContinuation {  continuation in
            self.messageList.retrieveMessageList {
                continuation.resume(returning: true)
            } withFailureBlock: {
                continuation.resume(returning: false)
            }
        }
    }

    func getMessage(messageID: String) async throws -> InboxMessage {
        if let message = self.messageList.message(forID: messageID) {
            guard !message.isExpired() else {
                throw MessageCenterMessageError.messageGone
            }
            return message
        }

        if await refreshMessages() {
            guard let message = self.messageList.message(forID: messageID) else {
                throw MessageCenterMessageError.messageGone
            }

            guard !message.isExpired() else {
                throw MessageCenterMessageError.messageGone
            }

            return message
        } else {
            throw MessageCenterMessageError.failedToFetchMessage
        }
    }

    func getAuth() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.user.getData({ data in
                guard let auth = Utils.authHeader(
                    username: data.username,
                    password: data.password
                ) else {
                    continuation.resume(throwing: AirshipErrors.error("Invalid auth"))
                    return
                }

                continuation.resume(returning: auth)
            })
        }
    }
}

