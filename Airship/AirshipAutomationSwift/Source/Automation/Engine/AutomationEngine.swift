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
    func schedule(_ schedules: [AutomationSchedule]) async throws

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
    private let queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()


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
    
    func schedule(_ schedules: [AutomationSchedule]) async throws {
        
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
        self.queue.enqueue {
            
        }
    }
}





