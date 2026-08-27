/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

import AirshipCore

fileprivate protocol AutomationExecutorProtocol: Sendable {
    @MainActor
    func isValid(
        schedule: AutomationSchedule
    ) async -> Bool

    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult

    @MainActor
    func checkFrequencyLimit(preparedSchedule: PreparedSchedule) -> Bool

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
    private let remoteDataAccess: any AutomationRemoteDataAccessProtocol

    init(
        actionExecutor: any AutomationExecutorDelegate<AirshipJSON>,
        messageExecutor: any AutomationExecutorDelegate<PreparedInAppMessageData>,
        remoteDataAccess: any AutomationRemoteDataAccessProtocol
    ) {
        self.actionExecutor = actionExecutor
        self.messageExecutor = messageExecutor
        self.remoteDataAccess = remoteDataAccess
    }

    @MainActor
    func isValid(schedule: AutomationSchedule) async -> Bool {
        return await self.remoteDataAccess.isCurrent(schedule: schedule)
    }

    /// Whether the schedule is ready to execute.
    ///
    /// Free of side effects on purpose: readiness is evaluated more than once per
    /// execution — again after waiting on a ledger group — so anything here that
    /// spent a budget would spend it twice. The frequency limit is charged
    /// separately, by ``checkFrequencyLimit(preparedSchedule:)``.
    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult {
        return switch (preparedSchedule.data) {
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
    }

    /// Charges the schedule's frequency budget, recording an occurrence.
    ///
    /// Call once, immediately before the execution it pays for — an occurrence
    /// spent on an execution that then gets skipped is gone for the rest of the
    /// constraint's window.
    ///
    /// - Returns: `true` if the schedule was under its frequency limits and the
    /// occurrence was recorded, `false` if it is over and should be skipped.
    @MainActor
    func checkFrequencyLimit(preparedSchedule: PreparedSchedule) -> Bool {
        return preparedSchedule.frequencyChecker?.checkAndIncrement() != false
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
