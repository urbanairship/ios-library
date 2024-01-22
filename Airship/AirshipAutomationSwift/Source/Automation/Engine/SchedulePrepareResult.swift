/* Copyright Airship and Contributors */

import Foundation

/// Schedule prepare result
enum SchedulePrepareResult: Sendable {
    case prepared(PreparedSchedule)
    case cancel
    case invalidate
    case skip
    case penalize
}
