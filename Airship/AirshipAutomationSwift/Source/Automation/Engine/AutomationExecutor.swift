/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationExecutorProtocol: Sendable {
    @MainActor
    func isReadyPrecheck(
        schedule: AutomationSchedule
    ) async -> ScheduleReadyResult

    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult

    @MainActor
    func execute(preparedSchedule: PreparedSchedule) async throws

    func interrupted(
        schedule: AutomationSchedule,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async
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
    ) async throws

    @MainActor
    func interrupted(
        preparedScheduleInfo: PreparedScheduleInfo
    ) async
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
    func isReadyPrecheck(schedule: AutomationSchedule) async -> ScheduleReadyResult {
        guard await self.remoteDataAccess.isCurrent(schedule: schedule) else {
            return .invalidate
        }

        return .ready
    }

    @MainActor
    func isReady(preparedSchedule: PreparedSchedule) -> ScheduleReadyResult {
        if (preparedSchedule.frequencyChecker?.checkAndIncrement() == false) {
            return .skip
        }

        switch (preparedSchedule.data) {
        case .inAppMessage(let data):
            return self.messageExecutor.isReady(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        case .actions(let data):
            return self.actionExecutor.isReady(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        }
    }

    @MainActor
    func execute(preparedSchedule: PreparedSchedule) async throws {
        switch (preparedSchedule.data) {
        case .inAppMessage(let data):
            try await self.messageExecutor.execute(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        case .actions(let data):
            try await self.actionExecutor.execute(
                data: data,
                preparedScheduleInfo: preparedSchedule.info
            )
        }
    }

    func interrupted(
        schedule: AutomationSchedule,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async {
        if schedule.isInAppMessageType {
            await self.messageExecutor.interrupted(
                preparedScheduleInfo: preparedScheduleInfo
            )
        } else {
            await self.actionExecutor.interrupted(
                preparedScheduleInfo: preparedScheduleInfo
            )
        }
    }
}


