import Foundation

@testable
import AirshipCore

public class TestContactAPIClient : ContactsAPIClientProtocol {
    
    var resolveCallback: ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var identifyCallback: ((String, String, String?, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var resetCallback: ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var updateCallback: ((String, [TagGroupUpdate]?, [AttributeUpdate]?, ((HTTPResponse?, Error?) -> Void)) -> Void)?
    var registerEmailCallback: (([EmailOptIn], String, ((ChannelCreateResponse?, Error?) -> Void)) -> Void)?
    var registerSmsCallback: ((String, String, Bool, ((ChannelCreateResponse?, Error?) -> Void)) -> Void)?
    var updateEmailCallback: ((String, [EmailOptIn], String, ((ChannelCreateResponse?, Error?) -> Void)) -> Void)?
    var updateSmsCallback: ((String, String, String, Bool, ((ChannelCreateResponse?, Error?) -> Void)) -> Void)?
    var optOutSmsCallback: ((String, String, ((ChannelCreateResponse?, Error?) -> Void)) -> Void)?
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
    
    public func registerEmail(emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        if let callback = registerEmailCallback {
            callback(emailOptIn, address, completionHandler)
        } else {
            defaultCallback?("registerEmail")
        }

        return Disposable()
    }
    
    public func registerSms(msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        if let callback = registerSmsCallback {
            callback(msisdn, sender, optedIn, completionHandler)
        } else {
            defaultCallback?("registerSms")
        }

        return Disposable()
    }
    
    public func updateEmail(channelID: String, emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        if let callback = updateEmailCallback {
            callback(channelID, emailOptIn, address, completionHandler)
        } else {
            defaultCallback?("updateEmail")
        }

        return Disposable()
    }
    
    public func updateSms(channelID: String, msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        if let callback = updateSmsCallback {
            callback(channelID, msisdn, sender, optedIn, completionHandler)
        } else {
            defaultCallback?("updateSms")
        }

        return Disposable()
    }
    
    public func optOutSms(msisdn: String, sender: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        if let callback = optOutSmsCallback {
            callback(msisdn, sender, completionHandler)
        } else {
            defaultCallback?("optOutSms")
        }
        
        return Disposable()
    }
}
