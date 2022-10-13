/* Copyright Airship and Contributors */

import Foundation
import CoreData

/// CoreData class representing the backing data for a UAInboxMessage.
/// This classs should not ordinarily be used directly.
@objc(UAInboxMessageData)
class InboxMessageData: NSManagedObject {
    
    static let messageDataEntity = "UAInboxMessage"


    @nonobjc public class func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: InboxMessageData.messageDataEntity)
    }

    @nonobjc public class func batchUpdateRequest() -> NSBatchUpdateRequest {
        return NSBatchUpdateRequest(entityName: InboxMessageData.messageDataEntity)
    }


    /// The Airship message ID.
    /// This ID may be used to match an incoming push notification to a specific message.
    @NSManaged public var messageID: String?
    
    /// The URL for the message body itself.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    @NSManaged public var messageBodyURL: URL?
    
    /// The URL for the message.
    /// This URL may only be accessed with Basic Auth credentials set to the user ID and password.
    @NSManaged public var messageURL: URL?
    
    /// The JSON object that contains the message ID, the group ID and the variant ID.
    @NSManaged public var messageReporting: [String: Any]?
    
    /// YES if the message is unread, otherwise NO.
    @NSManaged public var unread: Bool
    
    /// YES if the message is unread on the client, otherwise NO.
    @NSManaged public var unreadClient: Bool
    
    /// YES if the message is deleted, otherwise NO.
    @NSManaged public var deletedClient: Bool
    
    /// The date and time the message was sent (UTC)
    @NSManaged public var messageSent: Date?
    
    /// The date and time the message will expire.
    /// A nil value indicates it will never expire.
    @NSManaged public var messageExpiration: Date?
    
    /// The message title
    @NSManaged public var title: String?
    
    /// The message's extra dictionary. This dictionary can be populated
    /// with arbitrary key-value data at the time the message is composed.
    @NSManaged public var extra: [String: Any]?
    
    ///  The raw message dictionary. This is the dictionary that originally created the message.
    ///  It can contain more values then the message.
    @NSManaged public var rawMessageObject: [String: Any]?
}
