import Foundation

// NOTE: For internal use only. :nodoc:
enum SubscriptionListUpdateType : Int, Codable {
    case subscribe
    case unsubscribe
}

// NOTE: For internal use only. :nodoc:
struct SubscriptionListUpdate : Codable {
    let listId: String
    let type: SubscriptionListUpdateType
}
