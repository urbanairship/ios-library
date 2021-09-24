/* Copyright Airship and Contributors */

import Foundation

/**
 * Data class for decoding incoming message payloads to be sent when opening deeplinks or the OpenChatAction.
 */
struct ChatIncomingMessage:  Codable, Equatable {
    /**
     * The message text.
     */
    let message: String?
    /**
     * The attachement url.
     */
    let url: String?
    /**
     * The message date.
     */
    let date: Date?
    /**
     * The message id.
     */
    let messageID: String?
    
    enum CodingKeys: String, CodingKey {
        case message = "msg"
        case url = "url"
        case date = "date"
        case messageID = "id"
    }
    
    init(message: String?, url: String?, date: Date?, messageID: String?) {
        self.message = message
        self.url = url
        self.date = date
        self.messageID = messageID
    }
    
    static func == (lh: ChatIncomingMessage, rh: ChatIncomingMessage) -> Bool {
            return
                lh.message == rh.message &&
                lh.url == rh.url &&
                lh.date == rh.date &&
                lh.messageID == rh.messageID
        }
}
