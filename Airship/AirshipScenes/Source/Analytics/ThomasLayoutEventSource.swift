/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum ThomasLayoutEventSource: String, Encodable, Sendable {
    case airship = "urban-airship"
    case appDefined = "app-defined"
}
