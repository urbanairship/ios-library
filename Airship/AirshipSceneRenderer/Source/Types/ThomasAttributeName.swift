/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal)
public struct ThomasAttributeName: ThomasSerializable, Hashable {
    public var channel: String?
    public var contact: String?
}
