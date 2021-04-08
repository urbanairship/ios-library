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
    public let text: String

    /**
     * The message created date.
     */
    public let createdOn: Date

    init(requestID: String, text: String, createdOn: Date) {
        self.requestID = requestID
        self.text = text
        self.createdOn = createdOn
    }
}
