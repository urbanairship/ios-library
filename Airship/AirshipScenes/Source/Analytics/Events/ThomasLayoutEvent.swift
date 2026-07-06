/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
public import AirshipCore

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasLayoutEvent: Sendable {
    var name: AirshipEventType { get }
    var data: (any Sendable&Encodable)? { get }
}

extension ThomasLayoutEvent {
    var bodyJSON: AirshipJSON {
        get throws {
            try AirshipJSON.wrap(data)
        }
    }
}
