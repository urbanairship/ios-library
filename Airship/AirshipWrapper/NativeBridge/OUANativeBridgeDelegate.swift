/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

@objc
public protocol OUANativeBridgeDelegate {
    /// Called when `UAirship.close()` is triggered from the JavaScript environment.
    func close()
}

public class OUANativeBridgeDelegateWrapper: NSObject, NativeBridgeDelegate {
    private let delegate: OUANativeBridgeDelegate
    
    init(delegate: OUANativeBridgeDelegate) {
        self.delegate = delegate
    }
    
    public func close() {
        self.delegate.close()
    }
    
}
