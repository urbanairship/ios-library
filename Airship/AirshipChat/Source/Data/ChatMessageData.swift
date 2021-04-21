/* Copyright Airship and Contributors */

import Foundation
import CoreData

/**
 * Chat message data.
 */
@objc(UAChatMessageData)
class ChatMessageData : NSManagedObject, ChatMessageDataProtocol {

    /**
     * The message ID.
     */
    @NSManaged dynamic var messageID: Int

    /**
     * The message request ID.
     */
    @NSManaged dynamic var requestID: String?

    /**
     * The message text.
     */
    @NSManaged dynamic var text: String?

    /**
     * The message created date.
     */
    @NSManaged dynamic var createdOn: Date

    /**
     * The message source.
     */
    @NSManaged dynamic var direction: UInt

    /**
     * The message attachment.
     */
    @NSManaged dynamic var attachment: URL?
}
