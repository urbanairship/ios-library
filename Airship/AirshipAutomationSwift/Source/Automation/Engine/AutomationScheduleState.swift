/* Copyright Airship and Contributors */

import Foundation

enum AutomationScheduleState: Int, Equatable, Sendable {
    case idle = 0
    case preparing = 6
    case delayed = 5
    case waitingScheduleConditions = 1
    case executing = 2
    case paused = 3
    case finished = 4
}
