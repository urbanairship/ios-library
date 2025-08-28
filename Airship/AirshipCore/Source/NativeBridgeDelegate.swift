/* Copyright Airship and Contributors */



#if !os(tvOS) && !os(watchOS)

public protocol NativeBridgeDelegate: AnyObject {
    /// Called when `UAirship.close()` is triggered from the JavaScript environment.
    func close()
}

#endif
