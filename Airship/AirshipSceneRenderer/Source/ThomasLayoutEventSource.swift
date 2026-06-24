/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/// - Note: For internal use only. :nodoc:
public enum ThomasLayoutEventSource: String, Encodable, Sendable {
    case airship = "urban-airship"
    case appDefined = "app-defined"
}
