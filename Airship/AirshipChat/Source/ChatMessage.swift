/* Copyright Airship and Contributors */

import Foundation

/**
 * Message direction.
 */
@available(iOS 13.0, *)
@objc(UAChatMessageDirection)
public enum ChatMessageDirection: UInt {
    /**
     * Outgoing messages.
     */
    case outgoing = 0

    /**
     * Incoming messages.
     */
    case incoming = 1
}

/**
 * A chat message.
 */
@available(iOS 13.0, *)
@objc(UAChatMessage)
public class ChatMessage : NSObject {

    /**
     * The message ID.
     */
    @objc
    public let messageID: String

    /**
     * The message text.
     */
    @objc
    public let text: String?

    /**
     * The message created date.
     */
    @objc
    public let timestamp: Date

    /**
     * The message source.
     */
    @objc
    public let direction: ChatMessageDirection

    /**
     * Flag if the message is delivered or not.
     */
    @objc
    public let isDelivered : Bool

    /**
     * The message attachment.
     */
    @objc
    public let attachment: URL?

    init(messageID: String, text: String?, timestamp: Date, direction: ChatMessageDirection, delivered: Bool, attachment: URL? = nil) {
        self.messageID = messageID
        self.text = text
        self.timestamp = timestamp
        self.direction = direction
        self.isDelivered = delivered
        self.attachment = attachment
    }
}
