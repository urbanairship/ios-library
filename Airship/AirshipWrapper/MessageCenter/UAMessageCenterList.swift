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
    func _getMessages() async -> [UAMessageCenterMessage]

    /// Gets the user associated to the Message Center if there is one associated already.
    /// - Returns: the user associated to the Message Center, otherwise `nil`.
    @objc(getUserWithCompletionHandler:)
    func _getUser() async -> UAMessageCenterUser?

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
    func markRead(messages: [UAMessageCenterMessage]) async

    /// Marks messages read by message IDs.
    /// - Parameters:
    ///     - messageIDs: The list of message IDs for the messages to be marked read.
    @objc
    func markRead(messageIDs: [String]) async

    /// Marks messages deleted.
    /// - Parameters:
    ///     - messages: The list of messages to be marked deleted.
    @objc
    func delete(messages: [UAMessageCenterMessage]) async

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
    func message(forBodyURL bodyURL: URL) async -> UAMessageCenterMessage?

    /// Returns the message associated with a particular ID.
    /// - Parameters:
    ///     - messageID: The message ID.
    /// - Returns: The associated `MessageCenterMessage` object or nil if a message was unable to be found.
    @objc
    func message(forID messageID: String) async -> UAMessageCenterMessage?
}

@objc
final public class UAMessageCenterInbox: NSObject {
    
    @objc
    @discardableResult
    public func refreshMessages() async -> Bool {
        await MessageCenter.shared.inbox.refreshMessages()
    }

    @objc
    public func markRead(messages: [UAMessageCenterMessage]) async {
        await MessageCenter.shared.inbox.markRead(messages: messages.map{$0.mcMessage})
    }

    @objc
    public func markRead(messageIDs: [String]) async {
        await MessageCenter.shared.inbox.markRead(messageIDs: messageIDs)
    }

    @objc
    public func delete(messages: [UAMessageCenterMessage]) async {
        await MessageCenter.shared.inbox.delete(messages: messages.map{$0.mcMessage})
    }

    @objc
    public func delete(messageIDs: [String]) async {
        await MessageCenter.shared.inbox.delete(messageIDs: messageIDs)
    }

    @objc
    public func message(forBodyURL bodyURL: URL) async -> UAMessageCenterMessage?
    {
        guard let message = await MessageCenter.shared.inbox.message(forBodyURL: bodyURL) else { return nil }
        return UAMessageCenterMessage(message: message)
    }
}

public final class UAMessageCenterInboxBaseProtocolWrapper: NSObject, MessageCenterInboxBaseProtocol {
   
    private let delegate: UAMessageCenterInboxBaseProtocol
    
    init(delegate: UAMessageCenterInboxBaseProtocol) {
        self.delegate = delegate
    }
    
    public func _getMessages() async -> [MessageCenterMessage] {
        let messages = await self.delegate._getMessages()
        return messages.map { $0.mcMessage }
    }
    
    public func _getUser() async -> MessageCenterUser? {
        let user = await self.delegate._getUser()
        return user?.mcUser
    }
    
    public func _getUnreadCount() async -> Int {
        await self.delegate._getUnreadCount()
    }
    
    public func refreshMessages() async -> Bool {
        await self.delegate.refreshMessages()
    }
    
    public func markRead(messages: [MessageCenterMessage]) async {
        await self.delegate.markRead(messages: messages.map{UAMessageCenterMessage(message: $0)})
    }
    
    public func markRead(messageIDs: [String]) async {
        await self.delegate.markRead(messageIDs: messageIDs)
    }
    
    public func delete(messages: [MessageCenterMessage]) async {
        await self.delegate.delete(messages: messages.map{UAMessageCenterMessage(message: $0)})
    }
    
    public func delete(messageIDs: [String]) async {
        await self.delegate.delete(messageIDs: messageIDs)
    }
    
    public func message(forBodyURL bodyURL: URL) async -> MessageCenterMessage? {
        guard let message = await self.delegate.message(forBodyURL: bodyURL) else { return nil }
        return message.mcMessage
    }
    
    public func message(forID messageID: String) async -> MessageCenterMessage? {
        let message = await self.delegate.message(forID: messageID)
        return message?.mcMessage
    }
}
