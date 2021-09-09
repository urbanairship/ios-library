import Foundation

@testable
import AirshipCore

public class TestContactAPIClient : ContactsAPIClientProtocol {
    
    var resolveCallback: ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var identifyCallback: ((String, String, String?, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var resetCallback: ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var updateCallback: ((String, [TagGroupUpdate]?, [AttributeUpdate]?, ((HTTPResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    init() {}

    public func resolve(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {
        if let callback = resolveCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("resolve")
        }
        
        return Disposable()
    }
    
    public func identify(channelID: String, namedUserID: String, contactID: String?, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {
        if let callback = identifyCallback {
            callback(channelID, namedUserID, contactID, completionHandler)
        } else {
            defaultCallback?("identify")
        }
        
        return Disposable()
    }
    
    public func reset(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {
        if let callback = resetCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("reset")
        }

        return Disposable()
    }
    
    public func update(identifier: String, tagGroupUpdates: [TagGroupUpdate]?, attributeUpdates: [AttributeUpdate]?, completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {
        if let callback = updateCallback {
            callback(identifier, tagGroupUpdates, attributeUpdates, completionHandler)
        } else {
            defaultCallback?("update")
        }
        
        return Disposable()
    }
}
