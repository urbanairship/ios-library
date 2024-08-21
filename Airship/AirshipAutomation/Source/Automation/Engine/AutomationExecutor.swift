/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationExecutorProtocol: Sendable {
    @MainActor
    func isValid(
        schedule: AutomationSchedule
    ) async -> Bool

    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult

    @MainActor
    func execute(preparedSchedule: PreparedSchedule) async -> ScheduleExecuteResult

    func interrupted(
        schedule: AutomationSchedule,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async -> InterruptedBehavior
}

protocol AutomationExecutorDelegate<ExecutionData>: Sendable {
    associatedtype ExecutionData: Sendable
    
    @MainActor
    func isReady(
        data: ExecutionData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> ScheduleReadyResult

    @MainActor
    func execute(
        data: ExecutionData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> ScheduleExecuteResult

    @MainActor
    func interrupted(
        schedule: AutomationSchedule,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async -> InterruptedBehavior
}


final class AutomationExecutor: AutomationExecutorProtocol {
    private let actionExecutor: any AutomationExecutorDelegate<AirshipJSON>
    private let messageExecutor: any AutomationExecutorDelegate<PreparedInAppMessageData>
    private let remoteDataAccess: AutomationRemoteDataAccessProtocol

    init(
        actionExecutor: any AutomationExecutorDelegate<AirshipJSON>,
        messageExecutor: any AutomationExecutorDelegate<PreparedInAppMessageData>,
        remoteDataAccess: AutomationRemoteDataAccessProtocol
    ) {
        self.actionExecutor = actionExecutor
        self.messageExecutor = messageExecutor
        self.remoteDataAccess = remoteDataAccess
    }

    @MainActor
    func isValid(schedule: AutomationSchedule) async -> Bool {
        guard await self.remoteDataAccess.isCurrent(schedule: schedule) else {
            return false
        }

        return true
    }

    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult {
        let result = switch (preparedSchedule.data) {
        case .inAppMessage(let data):
            self.messageExecutor.isReady(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        case .actions(let data):
            self.actionExecutor.isReady(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        }

        guard result == .ready else {
            return result
        }

        if (preparedSchedule.frequencyChecker?.checkAndIncrement() == false) {
            return .skip
        }

        return .ready
    }

    @MainActor
    func execute(preparedSchedule: PreparedSchedule) async -> ScheduleExecuteResult {
        do {
            switch (preparedSchedule.data) {
            case .inAppMessage(let data):
                return try await self.messageExecutor.execute(
                    data: data,
                    preparedScheduleInfo: preparedSchedule.info
                )
            case .actions(let data):
                return try await self.actionExecutor.execute(
                    data: data,
                    preparedScheduleInfo: preparedSchedule.info
                )
            }
        } catch {
            AirshipLogger.warn("Failed to execute automation: \(preparedSchedule.info.scheduleID) error:\(error)")
            return .retry
        }
    }

    func interrupted(
        schedule: AutomationSchedule,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async -> InterruptedBehavior {
        return if schedule.isInAppMessageType {
            await self.messageExecutor.interrupted(
                schedule: schedule,
                preparedScheduleInfo: preparedScheduleInfo
            )
        } else {
            await self.actionExecutor.interrupted(
                schedule: schedule,
                preparedScheduleInfo: preparedScheduleInfo
            )
        }
    }
}

enum InterruptedBehavior: Sendable {
    case retry
    case finish
}
