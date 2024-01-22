/* Copyright Airship and Contributors */

import Foundation

/// Schedule ready result
enum ScheduleReadyResult: Sendable {
    case ready
    case invalidate
    case notReady
    case skip
}
