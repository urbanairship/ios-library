/* Copyright Airship and Contributors */

import Foundation

enum AutomationScheduleState: String, Equatable, Sendable {

    case idle
    case triggered
    case prepared
    case executing

    // interval
    case paused

    // waiting ot be cleaned up after grace period
    case finished
}
