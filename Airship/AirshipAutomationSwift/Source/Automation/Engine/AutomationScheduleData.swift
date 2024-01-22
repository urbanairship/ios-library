/* Copyright Airship and Contributors */

import Foundation

struct AutomationScheduleData: Sendable {
    var group: String?
    var identifier: String
    var startDate: Date
    var endDate: Date
    var schedule: Data
    var scheduleState: AutomationScheduleState
    var scheduleStateChangeDate: Date
    var excutionTriggeringInfo: TriggeringInfo?
    var limit: Int?
    var priority: Int
    var editGracePeriod: TimeInterval
    var interval: TimeInterval
}
