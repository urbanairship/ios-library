/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

struct TriggeringInfo: Equatable, Sendable, Codable {
    var context: AirshipTriggerContext?
    var date: Date
}
