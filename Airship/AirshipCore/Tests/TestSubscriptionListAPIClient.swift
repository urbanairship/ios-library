import Foundation

@testable
import AirshipCore

class TestSubscriptionListAPIClient : SubscriptionListAPIClientProtocol {
    var getCallback: ((String, ((SubscriptionListFetchResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    
    init() {}
    
    public func get(channelID: String, completionHandler: @escaping (SubscriptionListFetchResponse?, Error?) -> Void) -> Disposable {
        if let callback = getCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("get")
        }
        
        return Disposable()
    }
}
