import Foundation

@testable
import AirshipCore

class TestChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {
    
    var updateCallback: ((String, [SubscriptionListUpdate]?, [TagGroupUpdate]?, [AttributeUpdate]?, ((HTTPResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    
    init() {}
    
    func update(channelID: String, subscriptionListUpdates: [SubscriptionListUpdate]?, tagGroupUpdates: [TagGroupUpdate]?, attributeUpdates: [AttributeUpdate]?, completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {
        if let callback = updateCallback {
            callback(channelID, subscriptionListUpdates, tagGroupUpdates, attributeUpdates, completionHandler)
        } else {
            defaultCallback?("update")
        }
        
        return Disposable()
    }
}
