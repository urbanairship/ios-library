/* Copyright Airship and Contributors */

import Foundation

/**
 * Pending chat message data.
 */
class PendingChatMessageData : NSObject {

    /**
     * The message ID.
     */
    public let requestID: String

    /**
     * The message text.
     */
    public let text: String?

    /**
     * The message URL
     */
    public let attachment: URL?

    /**
     * The message created date.
     */
    public let createdOn: Date

    init(requestID: String, text: String?, attachment: URL?, createdOn: Date) {
        self.requestID = requestID
        self.text = text
        self.attachment = attachment
        self.createdOn = createdOn
    }
}
