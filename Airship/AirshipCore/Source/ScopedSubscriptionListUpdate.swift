/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
struct ScopedSubscriptionListUpdate : Codable, Equatable {
    let listId: String
    let type: SubscriptionListUpdateType
    let scope: ChannelScope
    let date: Date
}
