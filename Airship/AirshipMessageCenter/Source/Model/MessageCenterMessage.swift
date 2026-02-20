/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message center message.
public struct MessageCenterMessage: Sendable, Equatable, Identifiable, Hashable {
    private static let productIDKey = "product_id"

    /// The message title.
    public var title: String

    /// The Airship message ID.
    /// This ID may be used to match an incoming push notification to a specific message.
    public var id: String

    /// The message's extra dictionary.
    /// This dictionary can be populated with arbitrary key-value data at the time the message is composed.
    public var extra: [String: String]

    /// The URL for the message body itself.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    public var bodyURL: URL

    /// The date and time the message will expire.
    /// A nil value indicates it will never expire.
    public var expirationDate: Date?

    /// The date and time the message was sent (UTC).
    public var sentDate: Date

    /// The unread status of the message.
    /// `true` if the message is unread, otherwise `false`.
    public var unread: Bool
    
    /// The message center content type
    public let contentType: ContentType

    /// The reporting data of the message.
    let messageReporting: AirshipJSON?

    /// The URL for the message.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    let messageURL: URL

    /// The raw message dictionary.
    /// This is the dictionary that originally created the message.
    /// It can contain more values than the message.
    let rawMessageObject: AirshipJSON
    
    /// The message associated data
    var associatedData: AssociatedData
    
    public enum ContentType: Sendable, Hashable {
        case html
        case plain
        case native(version: Int)
        
        var jsonValue: String {
            switch self {
            case .html: return "text/html"
            case .plain: return "text/plain"
            case .native(let version): return "application/vnd.urbanairship.thomas+json;version=\(version);"
            }
        }
        
        static let nativeContentTypePrefix: String = "application/vnd.urbanairship.thomas+json"
        static func fromJson(value: String) -> ContentType? {
            if value == Self.html.jsonValue {
                return .html
            } else if value == Self.plain.jsonValue {
                return .plain
            } else if value.hasPrefix(Self.nativeContentTypePrefix) {
                guard let version = value
                    .replacingOccurrences(of: " ", with: "")
                    .components(separatedBy: ";")
                    .last(where: { $0.hasPrefix("version") })?
                    .components(separatedBy: "=")
                    .last
                    .flatMap(Int.init)
                else {
                    return nil
                }
                
                return .native(version: version)
            } else {
                return nil
            }
        }
    }

    init(
        title: String,
        id: String,
        contentType: ContentType,
        extra: [String: String],
        bodyURL: URL,
        expirationDate: Date?,
        messageReporting: [String: Any]?,
        unread: Bool,
        sentDate: Date,
        messageURL: URL,
        rawMessageObject: [String: Any],
        associatedData: Data? = nil
    ) {
        self.title = title
        self.id = id
        self.contentType = contentType
        self.extra = extra
        self.bodyURL = bodyURL
        self.expirationDate = expirationDate
        self.messageReporting = try? AirshipJSON.wrap(messageReporting)
        self.unread = unread
        self.sentDate = sentDate
        self.messageURL = messageURL
        self.rawMessageObject = (try? AirshipJSON.wrap(rawMessageObject))  ?? AirshipJSON.null
        self.associatedData = associatedData
            .flatMap { try? JSONDecoder().decode(MessageCenterMessage.AssociatedData.self, from: $0) }
            ?? AssociatedData()
    }
    
    public static func == (lhs: MessageCenterMessage, rhs: MessageCenterMessage) -> Bool {
        return lhs.rawMessageObject == rhs.rawMessageObject
    }
    
    struct AssociatedData: Codable, Sendable, Equatable, Hashable {
        var displayHistory: Data?
        var viewState: ViewState?
        
        func encoded() -> Data? {
            return try? JSONEncoder().encode(self)
        }
        
        struct ViewState: Codable, Sendable, Equatable, Hashable {
            var restoreID: String
            var state: Data?
        }
    }
}

extension MessageCenterMessage {
    /// The list icon of the message. `nil` if there is none.
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

    /// The subtitle of the message. `nil` if there is none.
    public var subtitle: String? {
        return self.extra["com.urbanairship.listing.field1"]
    }

    /// Parses the message ID.
    /// - Parameters:
    ///     - userInfo: The notification user info.
    /// - Returns: The message ID.
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

    /// Tells if the message is expired.
    /// `true` if the message is expired, otherwise `false`.
    public var isExpired: Bool {
        if let messageExpiration = self.expirationDate {
            let result = messageExpiration.compare(AirshipDate().now)
            return (result == .orderedAscending || result == .orderedSame)
        }
        return false
    }
    
    var productID: String? {
        return self.rawMessageObject.object?[Self.productIDKey]?.string
    }
}
