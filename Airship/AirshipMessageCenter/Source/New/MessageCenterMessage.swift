/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

public struct MessageCenterMessage: Decodable {
    
    var messageID: String
    var messageBodyURL: URL?
    var messageURL: URL?
    var contentType: String?
    var messageSent: Date?
    var messageExpiration: Date?
    var title: String?
    var extra: AirshipJSON?
    var rawMessageObject: AirshipJSON?
    var date: Date?
    var messageReporting: AirshipJSON?
    var unread: Bool

    private enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case title = "title"
        case contentType = "content_type"
        case messageBodyURL = "message_body_url"
        case messageURL = "message_url"
        case unread = "unread"
        case messageSent = "message_sent"
        case messageExpiration = "message_expiry"
        case extra = "extra"
        case rawMessageObject = "raw_message_object"
        case date = "date"
        case messageReporting = "message_reporting"
    }
    
}
