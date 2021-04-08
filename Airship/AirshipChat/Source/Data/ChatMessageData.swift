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
     * The message text.
     */
    public let text: String

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
    public let attachment: String?

    init(messageID: Int, text: String, createdOn: Date, direction: UInt, attachment: String?) {
        self.messageID = messageID
        self.text = text
        self.createdOn = createdOn
        self.direction = direction
        self.attachment = attachment
    }
}
