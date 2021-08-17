import Foundation

@testable
import AirshipCore

@objc(UATestChannelRegistrar)
public class TestChannelRegistrar : NSObject, ChannelRegistrarProtocol {
    @objc
    public var delegate: ChannelRegistrarDelegate?
    
    @objc
    public var channelID: String?
    
    @objc
    public var registerCalled = false
    
    @objc
    public var fullRegistrationCalled = false
    
    
    public func register(forcefully: Bool) {
        registerCalled = true
    }
    
    public func performFullRegistration() {
        fullRegistrationCalled = true
    }
    
    
}
