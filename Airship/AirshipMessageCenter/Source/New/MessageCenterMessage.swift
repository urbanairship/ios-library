/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/**
 * Message center message.
 */
@objc(UAMessageCenterMessage)
public class MessageCenterMessage: NSObject {
    public let title: String
    public let id: String
    public let extra: [String: String]
    public let bodyURL: URL
    public let expirationDate: Date?
    public let unread: Bool
    public let sentDate: Date

    let messageReporting: [String: Any]?
    let messageURL: URL
    let rawMessageObject: [String: Any]

    init(
        title: String,
        id: String,
        extra: [String: String],
        bodyURL: URL,
        expirationDate: Date?,
        messageReporting: [String: Any]?,
        unread: Bool,
        sentDate: Date,
        messageURL: URL,
        rawMessageObject: [String: Any]
    ) {
        self.title = title
        self.id = id
        self.extra = extra
        self.bodyURL = bodyURL
        self.expirationDate = expirationDate
        self.messageReporting = messageReporting
        self.unread = unread
        self.sentDate = sentDate
        self.messageURL = messageURL
        self.rawMessageObject = rawMessageObject
    }

    public override func isEqual(_ object: Any?) -> Bool {

        guard let object = object as? MessageCenterMessage,
              self.title == object.title,
              self.id == object.id,
              self.bodyURL == object.bodyURL,
              self.expirationDate == object.expirationDate,
              self.unread == object.unread,
              self.sentDate == object.sentDate,
              self.messageURL == object.messageURL,
              self.extra == object.extra,
              compare(self.messageReporting, object.messageReporting),
              compare(self.rawMessageObject, object.rawMessageObject)
        else {
            return false
        }


        return true
    }

    private func compare(
        _ first: [String: Any]?,
        _ second: [String: Any]?
    ) -> Bool {
        if (first == nil && second == nil) {
            return true
        }

        guard let first = first, let second = second else {
            return false
        }

        let result = NSDictionary(dictionary: first).isEqual(
            to: second
        )
        return result
        
    }

    public override var description: String {
        return "MessageCenterMessage(id=\(id))"
    }
}
