/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
public import AirshipCore


/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasLayoutDisplayEvent: ThomasLayoutEvent {
    public let name: AirshipEventType = AirshipEventType.inAppDisplay
    public let data: (any Sendable & Encodable)? = nil
    
    public init() {}
}
