/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
enum ScopedSubscriptionListUpdateType : Int, Codable {
    case subscribe
    case unsubscribe
}

// NOTE: For internal use only. :nodoc:
struct ScopedSubscriptionListUpdate : Codable {
    let listId: String
    let type: SubscriptionListUpdateType
    let scope: ChannelScope
    let timestamp: Date
}
