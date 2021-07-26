/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
protocol AirshipChannelProtocol {
    var identifier : String? { get }
    
    func updateRegistration()
    
    func addRegistrationExtender(_ extender: @escaping UAChannelRegistrationExtenderBlock)
}

extension UAChannel : AirshipChannelProtocol {
    public func addRegistrationExtender(_ extender: @escaping UAChannelRegistrationExtenderBlock) {
        if let extendable = self as? UAExtendableChannelRegistration {
            extendable.addChannelExtenderBlock(extender)
        }
    }
}
