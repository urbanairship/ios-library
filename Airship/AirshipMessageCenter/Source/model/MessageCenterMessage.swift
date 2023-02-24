/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message center message.
@objc(UAMessageCenterMessage)
public final class MessageCenterMessage: NSObject, Sendable {
    @objc
    public let title: String
    @objc
    public let id: String
    @objc
    public let extra: [String: String]
    @objc
    public let bodyURL: URL
    @objc
    public let expirationDate: Date?
    @objc
    public let sentDate: Date
    @objc
    public let unread: Bool

    let messageReporting: AirshipJSON?
    let messageURL: URL
    let rawMessageObject: AirshipJSON

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
        self.messageReporting = try? AirshipJSON.wrap(messageReporting)
        self.unread = unread
        self.sentDate = sentDate
        self.messageURL = messageURL
        self.rawMessageObject = (try? AirshipJSON.wrap(rawMessageObject))  ?? AirshipJSON.null
    }

    public override func isEqual(_ object: Any?) -> Bool {

        guard
            let object = object as? MessageCenterMessage,
            self.title == object.title,
            self.id == object.id,
            self.bodyURL == object.bodyURL,
            self.expirationDate == object.expirationDate,
            self.unread == object.unread,
            self.sentDate == object.sentDate,
            self.messageURL == object.messageURL,
            self.extra == object.extra,
            self.messageReporting == object.messageReporting,
            self.rawMessageObject == object.rawMessageObject
        else {
            return false
        }

        return true
    }
}

extension MessageCenterMessage {

    @objc
    public var listIcon: String? {
        guard
            let rawMessage = self.rawMessageObject.unWrap() as? [String: Any],
            let icons = rawMessage["icons"] as? [String: String],
            let listIcon = icons["list_icon"]
        else {
            return nil
        }
            
        return listIcon
    }

    @objc
    public var subtitle: String? {
        return self.extra["com.urbanairship.listing.field1"]
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
