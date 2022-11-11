/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
    import AirshipCore
#endif

/// Message center message.
@objc(UAMessageCenterMessage)
public class MessageCenterMessage: NSObject {
    @objc
    public let title: String
    @objc
    public let id: String
    @objc
    public let extra: [String: Any]
    @objc
    public let bodyURL: URL
    @objc
    public let expirationDate: Date?
    @objc
    public let sentDate: Date
    @objc
    public let unread: Bool

    let messageReporting: [String: Any]?
    let messageURL: URL
    let rawMessageObject: [String: Any]

    init(
        title: String,
        id: String,
        extra: [String: Any],
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
            compare(self.extra, object.extra),
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
        if first == nil && second == nil {
            return true
        }

        guard let first = first, let second = second else {
            return false
        }

        let result = NSDictionary(dictionary: first)
            .isEqual(
                to: second
            )
        return result

    }

    public override var description: String {
        return "MessageCenterMessage(id=\(id))"
    }
}

extension MessageCenterMessage {

    @objc
    public var listIcon: String? {
        let icons = self.rawMessageObject["icons"] as? [String: String]
        return icons?["list_icon"]
    }

    @objc
    public var subtitle: String? {
        return self.extra["com.urbanairship.listing.field1"] as? String
    }

    @objc
    public static func parseMessageID(userInfo: [AnyHashable: Any]) -> String? {
        guard let uamid = userInfo["_uamid"] else {
            return nil
        }

        if let uamid = uamid as? [String] {
            return uamid.first
        } else if let uamid = uamid as? String {
            return uamid
        } else {
            return nil
        }
    }

    @objc
    public var isExpired: Bool {
        if let messageExpiration = self.expirationDate {
            let result = messageExpiration.compare(AirshipDate().now)
            return (result == .orderedAscending || result == .orderedSame)
        }
        return false
    }
}
