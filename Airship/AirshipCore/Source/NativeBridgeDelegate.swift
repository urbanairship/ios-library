/* Copyright Airship and Contributors */

import Foundation

#if !os(tvOS) && !os(watchOS)

/// Delegate for native bridge events from web views.
public protocol NativeBridgeDelegate: AnyObject {
    /// Called when `UAirship.close()` is triggered from the JavaScript environment.
    func close()
}

#endif
