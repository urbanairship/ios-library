import Foundation

// NOTE: For internal use only. :nodoc:
enum SubscriptionListUpdateType: Int, Codable, Equatable, Sendable {
    case subscribe
    case unsubscribe
}

// NOTE: For internal use only. :nodoc:
struct SubscriptionListUpdate: Codable, Equatable, Sendable {
    let listId: String
    let type: SubscriptionListUpdateType
}
