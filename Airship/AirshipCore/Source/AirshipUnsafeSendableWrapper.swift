/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipUnsafeSendableWrapper<T>: @unchecked Sendable {
    public var value: T
    public init(_ value: T) {
        self.value = value
    }
}
