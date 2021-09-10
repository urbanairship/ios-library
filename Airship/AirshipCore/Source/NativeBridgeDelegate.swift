/* Copyright Airship and Contributors */

import Foundation

@objc(UANativeBridgeDelegate)
public protocol NativeBridgeDelegate {
    /**
     * Called when `UAirship.close()` is triggered from the JavaScript environment.
     */
    func close()
}
