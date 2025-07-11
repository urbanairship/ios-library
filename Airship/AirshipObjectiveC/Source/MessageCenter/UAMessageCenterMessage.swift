/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif

/// Message center message.
@objc
public final class UAMessageCenterMessage: NSObject, Sendable {

    let mcMessage: MessageCenterMessage

    init(message: MessageCenterMessage) {
        self.mcMessage = message
    }

    @objc
    /// The Airship message ID.
    /// This ID may be used to match an incoming push notification to a specific message.
    public var id: String {
        get {
            return mcMessage.id
        }
    }

    @objc
    /// The message title.
    public var title: String {
        get {
            return mcMessage.title
        }
    }

    @objc
    /// The message subtitle.
    public var subtitle: String? {
        get {
            return mcMessage.subtitle
        }
    }

    @objc
    /// The message list icon.
    public var listIcon: String? {
        get {
            return mcMessage.listIcon
        }
    }

    @objc
    /// The message expiry.
    public var isExpired: Bool {
        get {
            return mcMessage.isExpired
        }
    }

    @objc
    /// The message's extra dictionary.
    /// This dictionary can be populated with arbitrary key-value data at the time the message is composed.
    public var extra: [String: String] {
        get {
            return mcMessage.extra
        }
    }

    @objc
    /// The URL for the message body itself.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    public var bodyURL: URL {
        get {
            return mcMessage.bodyURL
        }
    }

    @objc
    /// The date and time the message will expire.
    /// A nil value indicates it will never expire.
    public var expirationDate: Date? {
        get {
            return mcMessage.expirationDate
        }
    }


    @objc
    /// The date and time the message was sent (UTC).
    public var sentDate: Date {
        get {
            return mcMessage.sentDate
        }
    }

    @objc
    /// The unread status of the message.
    /// `true` if the message is unread, otherwise `false`.
    public var unread: Bool {
        get {
            return mcMessage.unread
        }
    }

    /// Parses the message ID from notification user info.
    /// - Parameters:
    ///     - userInfo: The notification user info.
    /// - Returns: The message ID.
    @objc(parseMessageIDFromUserInfo:)
    public class func parseMessageID(userInfo: [AnyHashable: Any]) -> String? {
        return MessageCenterMessage.parseMessageID(userInfo: userInfo)
    }

}
