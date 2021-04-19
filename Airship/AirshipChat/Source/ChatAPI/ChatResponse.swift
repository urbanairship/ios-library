/* Copyright Airship and Contributors */

import Foundation

/**
 * Chat responses.
 */
struct ChatResponse : Decodable {

    let type: String;
    let payload: Any?;

    enum CodingKeys: String, CodingKey {
        case payload = "payload"
        case type = "type"
    }

    init(type: String, payload: Any?) {
        self.type = type
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)

        switch type {
        case "conversation_loaded":
            self.payload = try container.decode(ConversationLoadedResponsePayload.self, forKey: .payload)
        case "message_received":
            self.payload = try container.decode(SentMessageResponsePayload.self, forKey: .payload)
        case "new_message":
            self.payload = try container.decode(NewMessageResponsePayload.self, forKey: .payload)
        default:
            AirshipLogger.error("Unexpected type: \(type)")
            self.payload = nil
        }
    }

    /**
     * Chat message.
     */
    struct Message: Decodable {
        let messageID: Int
        let createdOn: Date
        let direction: UInt
        let text: String
        let attachment: URL?
        let requestID: String?

        enum CodingKeys: String, CodingKey {
            case messageID = "message_id"
            case createdOn = "created_on"
            case direction = "direction"
            case text = "text"
            case attachment = "attachment"
            case requestID = "request_id"
        }
    }

    /**
     * Response when a message was received.
     */
    struct SentMessageResponsePayload: Decodable {
        let message: Message

        enum CodingKeys: String, CodingKey {
            case message = "message"
        }
    }

    /**
     * Response when a new message is received.
     */
    struct NewMessageResponsePayload: Decodable {
        let message: Message

        enum CodingKeys: String, CodingKey {
            case message = "message"
        }
    }

    /**
     * Response when a conversation response was recieved.
     */
    struct ConversationLoadedResponsePayload: Decodable {
        let messages: [Message]?

        enum CodingKeys: String, CodingKey {
            case messages = "messages"
        }
    }
}
