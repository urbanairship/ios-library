/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public class AirshipWeakValueHolder<T: AnyObject> {
    public weak var value: T?

    public init(value: T? = nil) {
        self.value = value
    }
}
