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

    func stopSchedules(_ schedules: [AutomationSchedule]) async throws
    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws

    func cancelSchedule(identifier: String) async throws
    func cancelSchedules(group: String) async throws

    var schedules: [AutomationSchedule] { get async throws }
    func getSchedule(identifier: String) async throws -> AutomationSchedule
    func getSchedules(group: String) async throws -> [AutomationSchedule]

    func scheduleConditionsChanged()
}

final class AutomationEngine : AutomationEngineProtocol, @unchecked Sendable {

    var isPaused: Bool = false
    var isExecutionPaused: Bool = false

    private let executor: AutomationExecutor
    private let preparer: AutomationPreparer
    private let conditionsChangedNotifier: Notifier


    init(
        executor: AutomationExecutor,
        preparer: AutomationPreparer,
        conditionsChangedNotifier: Notifier
    ) {
        self.executor = executor
        self.preparer = preparer
        self.conditionsChangedNotifier = conditionsChangedNotifier
    }


    func start() {
        Task {
            await self.conditionsChangedNotifier.addOnNotify {
                self.scheduleConditionsChanged()
            }
        }
    }

    func stopSchedules(_ schedules: [AutomationSchedule]) async throws {

    }

    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {

    }

    func cancelSchedule(identifier: String) async throws {

    }

    func cancelSchedules(group: String) async throws {

    }

    var schedules: [AutomationSchedule] {
        return []
    }

    func getSchedule(identifier: String) async throws -> AutomationSchedule {
        throw AirshipErrors.error("failed")
    }

    func getSchedules(group: String) async throws -> [AutomationSchedule] {
        return []
    }

    func scheduleConditionsChanged() {

    }

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
    var reportingContext: AirshipJSON?

    init(
        scheduleID: String,
        campaigns: AirshipJSON? = nil,
        contactID: String? = nil,
        experimentResult: ExperimentResult? = nil,
        reportingContext: AirshipJSON? = nil
    ) {
        self.scheduleID = scheduleID
        self.campaigns = campaigns
        self.contactID = contactID
        self.experimentResult = experimentResult
        self.reportingContext = reportingContext
    }
}

/// Prepared schedule data
enum PreparedScheduleData {
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


