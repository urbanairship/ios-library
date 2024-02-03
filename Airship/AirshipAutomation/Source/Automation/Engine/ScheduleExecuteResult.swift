/* Copyright Airship and Contributors */

import Foundation

/// Schedule execute result
enum ScheduleExecuteResult: Sendable {
    case cancel
    case finished
    case retry
}
