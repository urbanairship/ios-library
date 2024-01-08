/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Automation engine
protocol AutomationEngineProtocol: AnyObject, Sendable {
    var isPaused: Bool { get set }
    var isExecutionPaused: Bool { get set }
    func start()

    func scheduleConditionsChanged()
    func cancelSchedule(identifier: String) async
    func cancelSchedule(group: String) async
    func schedule(_ schedules: [AutomationSchedule]) async throws
    var schedules: [AutomationSchedule] { get async }
}

/// A prepared schedule
struct PreparedSchedule: Sendable {
    let info: PreparedScheduleInfo
    let data: PreparedScheduleData
    let frequencyChecker: FrequencyCheckerProtocol?
}

/// Persisted info for a schedule that has been prepared for execution
struct PreparedScheduleInfo: Codable, Equatable {
    var scheduleID: String
    var campaigns: AirshipJSON?
    var contactID: String?
    var experimentResult: ExperimentResult?
}

/// Prepared schedule data
enum PreparedScheduleData: Codable, Equatable {
    case inAppMessage(PreparedInAppMessageData)
    case actions(AirshipJSON)
}

/// Schedule prepare result
enum SchedulePrepareResult: Sendable {
    case prepared(PreparedSchedule)
    case cancel
    case invalidate
    case skip
    case penalize
}

/// Schedule ready result
enum ScheduleReadyResult: Sendable {
    case ready
    case invalidate
    case notReady
    case skip
}


