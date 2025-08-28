/* Copyright Airship and Contributors */


@testable import AirshipAutomation
@testable import AirshipCore

final class TestInAppMessageAutomationExecutor: AutomationExecutorDelegate, @unchecked Sendable {  typealias ExecutionData = PreparedInAppMessageData
    func isReady(data: AirshipAutomation.PreparedInAppMessageData, preparedScheduleInfo: AirshipAutomation.PreparedScheduleInfo) -> AirshipAutomation.ScheduleReadyResult {
        return .ready
    }
    
    func execute(data: AirshipAutomation.PreparedInAppMessageData, preparedScheduleInfo: AirshipAutomation.PreparedScheduleInfo) async throws -> AirshipAutomation.ScheduleExecuteResult {
        return .finished
    }
    
    func interrupted(schedule: AirshipAutomation.AutomationSchedule, preparedScheduleInfo: AirshipAutomation.PreparedScheduleInfo) async -> AirshipAutomation.InterruptedBehavior {
        return .finish
    }
    
}
