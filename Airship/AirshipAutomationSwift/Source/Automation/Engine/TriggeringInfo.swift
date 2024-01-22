/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct TriggeringInfo: Equatable, Sendable, Codable {
    var context: AirshipTriggerContext
    var date: Date
}

