import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-App messaging
public protocol InAppMessagingProtocol: Sendable {
}

final class InAppMessaging: InAppMessagingProtocol {

}

/// Any data needed by in-app message to handle displaying the message
struct PreparedInAppMessageData: Sendable, Codable, Equatable {
}


extension InAppMessage: AutomationPreparerDelegate {
    typealias PrepareDataIn = InAppMessage
    typealias PrepareDataOut = PreparedInAppMessageData

    func prepare(data: InAppMessage, preparedScheduleInfo: PreparedScheduleInfo) async throws -> PreparedInAppMessageData {
        // TODO:
        // - extend IAM
        // - prepare assets
        // - create display coordinator
        // - create display adapter

        return PreparedInAppMessageData()
    }
    
    func cancelled(scheduleID: String) async {
        // TODO: Clean up asssets
    }
}

extension InAppMessaging: AutomationExecutorDelegate {
    typealias ExecutionData = PreparedInAppMessageData

    func isReady(data: PreparedInAppMessageData, preparedScheduleInfo: PreparedScheduleInfo) -> ScheduleReadyResult {
        // TODO:
        // check if display adapter is ready
        // check if coordinator is ready
        // check delegate is message is ready for display

        return .ready
    }
    
    func execute(data: PreparedInAppMessageData, preparedScheduleInfo: PreparedScheduleInfo) async {
        // TODO:
        // if experiment, experiment event
        // display adapter.display
    }
    
    func interrupted(preparedScheduleInfo: PreparedScheduleInfo) async {
        // TODO:
        // resolution event
    }

}


/// Internal protocol
protocol InternalInAppMessagingProtocol: Sendable  {

    func prepare(
        message: InAppMessage,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> PreparedInAppMessageData

    @MainActor
    func isReadyToDisplay(
        data: PreparedInAppMessageData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> ScheduleReadyResult

    @MainActor
    func display(
        data: PreparedInAppMessageData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async

    @MainActor
    func displayInterrupted(
        preparedScheduleInfo: PreparedScheduleInfo
    ) async

    func displayCancelled(scheduleID: String) async
}

