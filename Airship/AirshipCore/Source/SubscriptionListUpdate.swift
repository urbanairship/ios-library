import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UASubscriptionListUpdateType)
public enum SubscriptionListUpdateType : Int, Codable {
    case subscribe
    case unsubscribe
}

// NOTE: For internal use only. :nodoc:
@objc(UASubscriptionListUpdate)
public class SubscriptionListUpdate : NSObject {
    let listId: String
    let type: SubscriptionListUpdateType
    
    @objc
    public init(listId: String, type: SubscriptionListUpdateType) {
        self.listId = listId
        self.type = type       
        super.init()
    }
}
