/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif
import Combine

/// Message center inbox.
@objc
public final class UAMessageCenterInbox: NSObject, Sendable {

    @objc
    public func getMessages() async -> [UAMessageCenterMessage] {
        let messages = await Airship.messageCenter.inbox.messages
        return messages.map { UAMessageCenterMessage(message: $0) }
    }

    @objc
    public func getUser() async -> UAMessageCenterUser? {
        guard let user = await Airship.messageCenter.inbox.user else {
            return nil
        }
        return UAMessageCenterUser(user: user)
    }

    @objc
    public func getUnreadCount() async -> Int {
        await Airship.messageCenter.inbox.unreadCount
    }

    @objc
    public func message(forBodyURL bodyURL: URL) async -> UAMessageCenterMessage? {
        guard let message = await Airship.messageCenter.inbox.message(forBodyURL: bodyURL) else { return nil }
        return UAMessageCenterMessage(message: message)
    }

    @objc
    public func message(forID messageID: String) async -> UAMessageCenterMessage? {
        guard let message = await Airship.messageCenter.inbox.message(forID: messageID) else {
            return nil
        }

        return UAMessageCenterMessage(message: message)
    }

    @objc
    @discardableResult
    public func refreshMessages() async -> Bool {
        await Airship.messageCenter.inbox.refreshMessages()
    }

    @objc
    public func markRead(messages: [UAMessageCenterMessage]) async {
        await Airship.messageCenter.inbox.markRead(messages: messages.map{$0.mcMessage})
    }

    @objc
    public func markRead(messageIDs: [String]) async {
        await Airship.messageCenter.inbox.markRead(messageIDs: messageIDs)
    }

    @objc
    public func delete(messages: [UAMessageCenterMessage]) async {
        await Airship.messageCenter.inbox.delete(messages: messages.map{$0.mcMessage})
    }

    @objc
    public func delete(messageIDs: [String]) async {
        await Airship.messageCenter.inbox.delete(messageIDs: messageIDs)
    }
}
