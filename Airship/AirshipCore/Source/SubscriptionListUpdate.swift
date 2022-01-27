import Foundation

// NOTE: For internal use only. :nodoc:
enum SubscriptionListUpdateType : Int, Codable, Equatable {
    case subscribe
    case unsubscribe
}

// NOTE: For internal use only. :nodoc:
struct SubscriptionListUpdate : Codable, Equatable {
    let listId: String
    let type: SubscriptionListUpdateType
}
