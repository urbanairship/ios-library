/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

struct TriggeringInfo: Equatable, Sendable, Codable {
    var context: AirshipTriggerContext?
    var date: Date
}
