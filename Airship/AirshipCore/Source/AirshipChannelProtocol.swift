/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
protocol AirshipChannelProtocol {
    var identifier : String? { get }
    
    func updateRegistration()
}

extension UAChannel : AirshipChannelProtocol {}
