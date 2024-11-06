/* Copyright Airship and Contributors */

import Foundation
public import AirshipMessageCenter
import Combine

/// Airship Message Center inbox base protocol.
@objc(UAMessageCenterInboxProtocol)
public protocol UAMessageCenterInboxBaseProtocol: AnyObject, Sendable {

    /// Gets the list of messages in the inbox.
    /// - Returns: the list of messages in the inbox.
    @objc(getMessagesWithCompletionHandler:)
    func _getMessages() async -> [MessageCenterMessage]

    /// Gets the user associated to the Message Center if there is one associated already.
    /// - Returns: the user associated to the Message Center, otherwise `nil`.
    @objc(getUserWithCompletionHandler:)
    func _getUser() async -> MessageCenterUser?

    /// Gets the number of messages that are currently unread.
    /// - Returns: the number of messages that are currently unread.
    @objc(getUnreadCountWithCompletionHandler:)
    func _getUnreadCount() async -> Int

    /// Refreshes the list of messages in the inbox.
    /// - Returns: `true` if the messages was refreshed, otherwise `false`.
    @objc
    @discardableResult
    func refreshMessages() async -> Bool

    /// Marks messages read.
    /// - Parameters:
    ///     - messages: The list of messages to be marked read.
    @objc
    func markRead(messages: [MessageCenterMessage]) async

    /// Marks messages read by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked read.
    @objc
    func markRead(messageIDs: [String]) async

    /// Marks messages deleted.
    /// - Parameters:
    ///     - messages: The list of messages to be marked deleted.
    @objc
    func delete(messages: [MessageCenterMessage]) async

    /// Marks messages deleted by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked deleted.
    @objc
    func delete(messageIDs: [String]) async

    /// Returns the message associated with a particular URL.
    /// - Parameters:
    ///     - bodyURL: The URL of the message.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    @objc
    func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage?

    /// Returns the message associated with a particular ID.
    /// - Parameters:
    ///     - messageID: The message ID.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    @objc
    func message(forID messageID: String) async -> MessageCenterMessage?
}

@objc
final public class UAMessageCenterInbox: NSObject {
    
    @objc
    @discardableResult
    public func refreshMessages() async -> Bool {
        await MessageCenter.shared.inbox.refreshMessages()
    }

    @objc
    public func markRead(messages: [MessageCenterMessage]) async {
        await MessageCenter.shared.inbox.markRead(messages: messages)
    }

    @objc
    public func markRead(messageIDs: [String]) async {
        await MessageCenter.shared.inbox.markRead(messageIDs: messageIDs)
    }

    @objc
    public func delete(messages: [MessageCenterMessage]) async {
        await MessageCenter.shared.inbox.delete(messages: messages)
    }

    @objc
    public func delete(messageIDs: [String]) async {
        await MessageCenter.shared.inbox.delete(messageIDs: messageIDs)
    }

    @objc
    public func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage?
    {
        return await MessageCenter.shared.inbox.message(forBodyURL: bodyURL)
    }
}
