import Foundation

@testable
import AirshipCore

public class TestSubscriptionListAPIClient : SubscriptionListAPIClientProtocol {
    
    var updateCallback: ((String, [SubscriptionListUpdate], ((UAHTTPResponse?, Error?) -> Void)) -> Void)?
    var getCallback: ((String, ((SubscriptionListFetchResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    
    init() {}

    public func update(channelID: String, subscriptionLists: [SubscriptionListUpdate], completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {
        if let callback = updateCallback {
            callback(channelID, subscriptionLists, completionHandler)
        } else {
            defaultCallback?("update")
        }
        
        return UADisposable()
    }
    
    public func get(channelID: String, completionHandler: @escaping (SubscriptionListFetchResponse?, Error?) -> Void) -> UADisposable {
        if let callback = getCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("get")
        }
        
        return UADisposable()
    }
}
