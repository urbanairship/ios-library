import Foundation

@testable
import AirshipCore

public class TestChannel : AirshipChannelProtocol {
    public var identifier: String? = nil
    public var updateRegistrationCalled : Bool = false
    
    public func updateRegistration() {
        self.updateRegistrationCalled = true
    }
}
