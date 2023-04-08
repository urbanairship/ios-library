/* Copyright Airship and Contributors */

import Foundation

#if !os(tvOS) && !os(watchOS)

@objc(UANativeBridgeDelegate)
public protocol NativeBridgeDelegate {
    /// Called when `UAirship.close()` is triggered from the JavaScript environment.
    func close()
}

#endif
