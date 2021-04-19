/* Copyright Airship and Contributors */

import Foundation

/**
 * Chat message data.
 */
class ChatMessageData : NSObject {

    /**
     * The message ID.
     */
    public let messageID: Int

    /**
     * The message request ID.
     */
    public let requestID: String?

    /**
     * The message text.
     */
    public let text: String?

    /**
     * The message created date.
     */
    public let createdOn: Date

    /**
     * The message source.
     */
    public let direction: UInt

    /**
     * The message attachment.
     */
    public let attachment: URL?

    init(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?) {
        self.messageID = messageID
        self.requestID = requestID
        self.text = text
        self.createdOn = createdOn
        self.direction = direction
        self.attachment = attachment
    }
}
