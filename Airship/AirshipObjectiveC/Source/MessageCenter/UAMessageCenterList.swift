/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif

/// Message center inbox.
@objc
public final class UAMessageCenterInbox: NSObject, Sendable {

    /// The list of messages in the inbox.
    @objc
    public func getMessages() async -> [UAMessageCenterMessage] {
        let messages = await Airship.messageCenter.inbox.messages
        return messages.map { UAMessageCenterMessage(message: $0) }
    }

    /// The user associated to the Message Center
    @objc
    public func getUser() async -> UAMessageCenterUser? {
        guard let user = await Airship.messageCenter.inbox.user else {
            return nil
        }
        return UAMessageCenterUser(user: user)
    }

    /// The number of messages that are currently unread.
    @objc
    public func getUnreadCount() async -> Int {
        await Airship.messageCenter.inbox.unreadCount
    }

    /// Returns the message associated with a particular URL.
    /// - Parameters:
    ///     - bodyURL: The URL of the message.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    @objc
    public func message(forBodyURL bodyURL: URL) async -> UAMessageCenterMessage? {
        guard let message = await Airship.messageCenter.inbox.message(forBodyURL: bodyURL) else { return nil }
        return UAMessageCenterMessage(message: message)
    }

    /// Returns the message associated with a particular ID.
    /// - Parameters:
    ///     - messageID: The message ID.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    @objc
    public func message(forID messageID: String) async -> UAMessageCenterMessage? {
        guard let message = await Airship.messageCenter.inbox.message(forID: messageID) else {
            return nil
        }

        return UAMessageCenterMessage(message: message)
    }

    /// Refreshes the list of messages in the inbox.
    /// - Returns: `true` if the messages was refreshed, otherwise `false`.
    @objc
    @discardableResult
    public func refreshMessages() async -> Bool {
        await Airship.messageCenter.inbox.refreshMessages()
    }
    
    /// Marks messages read.
    /// - Parameters:
    ///     - messages: The list of messages to be marked read.
    @objc
    public func markRead(messages: [UAMessageCenterMessage]) async {
        await Airship.messageCenter.inbox.markRead(messages: messages.map{$0.mcMessage})
    }

    /// Marks messages read by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked read.
    @objc
    public func markRead(messageIDs: [String]) async {
        await Airship.messageCenter.inbox.markRead(messageIDs: messageIDs)
    }

    /// Marks messages deleted.
    /// - Parameters:
    ///     - messages: The list of messages to be marked deleted.
    @objc
    public func delete(messages: [UAMessageCenterMessage]) async {
        await Airship.messageCenter.inbox.delete(messages: messages.map{$0.mcMessage})
    }

    /// Marks messages deleted by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked deleted.
    @objc
    public func delete(messageIDs: [String]) async {
        await Airship.messageCenter.inbox.delete(messageIDs: messageIDs)
    }
}
