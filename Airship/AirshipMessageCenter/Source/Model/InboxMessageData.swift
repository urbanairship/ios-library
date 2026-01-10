/* Copyright Airship and Contributors */

import CoreData
import Foundation

/// CoreData class representing the backing data for a UAInboxMessage.
/// This class should not ordinarily be used directly.
@objc(UAInboxMessageData)
class InboxMessageData: NSManagedObject {

    static let messageDataEntity = "UAInboxMessage"

    @nonobjc class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: InboxMessageData.messageDataEntity)
    }

    @nonobjc class func batchUpdateRequest() -> NSBatchUpdateRequest {
        return NSBatchUpdateRequest(
            entityName: InboxMessageData.messageDataEntity
        )
    }

    /// The Airship message ID.
    /// This ID may be used to match an incoming push notification to a specific message.
    @NSManaged var messageID: String?

    /// The URL for the message body itself.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    @NSManaged var messageBodyURL: URL?

    /// The URL for the message.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    @NSManaged var messageURL: URL?

    /// The data object that contains the message ID, the group ID and the variant ID.
    @NSManaged var messageReporting: Data?

    /// YES if the message is unread, otherwise NO.
    @NSManaged var unread: Bool

    /// YES if the message is unread on the client, otherwise NO.
    @NSManaged var unreadClient: Bool

    /// YES if the message is deleted, otherwise NO.
    @NSManaged var deletedClient: Bool

    /// The date and time the message was sent (UTC)
    @NSManaged var messageSent: Date?

    /// The date and time the message will expire.
    /// A nil value indicates it will never expire.
    @NSManaged var messageExpiration: Date?

    /// The message title
    @NSManaged var title: String?

    /// The message's extra dictionary. This dictionary can be populated
    /// with arbitrary key-value data at the time the message is composed.
    @NSManaged var extra: Data?

    ///  The raw message dictionary. This is the dictionary that originally created the message.
    ///  It can contain more values then the message.
    @NSManaged var rawMessageObject: Data?
    
    /// The message content type
    @NSManaged var contentType: String?
}
