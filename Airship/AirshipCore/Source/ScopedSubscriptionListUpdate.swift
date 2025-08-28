/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
struct ScopedSubscriptionListUpdate: Codable, Equatable, Sendable {
    let listId: String
    let type: SubscriptionListUpdateType
    let scope: ChannelScope
    let date: Date
}
