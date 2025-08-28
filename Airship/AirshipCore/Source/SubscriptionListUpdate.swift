

/// NOTE: For internal use only. :nodoc:
enum SubscriptionListUpdateType: Int, Codable, Equatable, Sendable {
    case subscribe
    case unsubscribe
}

/// NOTE: For internal use only. :nodoc:
struct SubscriptionListUpdate: Codable, Equatable, Sendable {
    let listId: String
    let type: SubscriptionListUpdateType
}


extension SubscriptionListUpdate {
    var operation: SubscriptionListOperation {
        switch self.type {
        case .subscribe:
            return SubscriptionListOperation(
                action: .subscribe,
                listID: self.listId
            )
        case .unsubscribe:
            return SubscriptionListOperation(
                action: .unsubscribe,
                listID: self.listId
            )
        }
    }
}

/// NOTE: For internal use only. :nodoc:
// Used by ChannelBulkAPIClient and DeferredAPIClient
struct SubscriptionListOperation: Encodable {
    enum SubscriptionAction: String, Encodable {
        case subscribe
        case unsubscribe
    }

    var action: SubscriptionAction
    var listID: String

    enum CodingKeys: String, CodingKey {
        case action = "action"
        case listID = "list_id"
    }
}
