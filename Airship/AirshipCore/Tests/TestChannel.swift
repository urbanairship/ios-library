import Foundation

@testable
import AirshipCore

public class TestChannel : AirshipChannelProtocol {
    
    public var extenders : [UAChannelRegistrationExtenderBlock] = []
    public var identifier: String? = nil
    public var updateRegistrationCalled : Bool = false
    
    public func updateRegistration() {
        self.updateRegistrationCalled = true
    }
    
    public func addRegistrationExtender(_ extender: @escaping UAChannelRegistrationExtenderBlock) {
        extenders.append(extender)
    }
    
}
