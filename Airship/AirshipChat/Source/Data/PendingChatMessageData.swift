/* Copyright Airship and Contributors */

import Foundation
import CoreData

/**
 * Pending chat message data.
 */
@objc(UAPendingChatMessageData)
class PendingChatMessageData : NSManagedObject, PendingChatMessageDataProtocol {
    /**
     * The message ID.
     */
    @NSManaged dynamic var requestID: String

    /**
     * The message text.
     */
    @NSManaged dynamic var text: String?

    /**
     * The message URL
     */
    @NSManaged dynamic var attachment: URL?

    /**
     * The message created date.
     */
    @NSManaged dynamic var createdOn: Date
}
