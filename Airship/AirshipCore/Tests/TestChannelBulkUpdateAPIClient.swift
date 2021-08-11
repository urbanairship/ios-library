import Foundation

@testable
import AirshipCore

class TestChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {
    
    var updateCallback: ((String, [SubscriptionListUpdate]?, [TagGroupUpdate]?, [AttributeUpdate]?, ((UAHTTPResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    
    init() {}
    
    func update(channelID: String, subscriptionListUpdates: [SubscriptionListUpdate]?, tagGroupUpdates: [TagGroupUpdate]?, attributeUpdates: [AttributeUpdate]?, completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {
        if let callback = updateCallback {
            callback(channelID, subscriptionListUpdates, tagGroupUpdates, attributeUpdates, completionHandler)
        } else {
            defaultCallback?("update")
        }
        
        return UADisposable()
    }
}
