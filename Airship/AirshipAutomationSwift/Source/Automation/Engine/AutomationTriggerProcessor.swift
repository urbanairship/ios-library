/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationTriggerProcessorProtocol: Sendable {
    @MainActor
    func setPaused(_ paused: Bool)
    
    var triggerResults: AsyncStream<TriggerResult> { get async }

    func processEvent(
        _ event: AutomationEvent
    ) async

    func restoreSchedules(
        _ datas: [AutomationScheduleData]
    ) async throws

    func updateSchedule(
        _ data: AutomationScheduleData
    ) async throws

    func updateSchedules(
        _ datas: [AutomationScheduleData]
    ) async

    /// Cancels/deletes all data for the given schedule ids
    func cancel(scheduleIDs: [String]) async

    /// Cancels/deletes all data for the given group
    func cancel(group: String) async
}


final class AutomationTriggerProcessor: AutomationTriggerProcessorProtocol {
    let queue : AirshipSerialQueue = AirshipSerialQueue()

    @MainActor
    func setPaused(_ paused: Bool) {

    }

    var triggerResults: AsyncStream<TriggerResult> {
        return AsyncStream { _ in

        }
    }

    // check triggers for events
    func processEvent(_ event: AutomationEvent) async {
        await self.queue.runSafe {

        }

    }


    // check state triggers
    func restoreSchedules(_ datas: [AutomationScheduleData]) async throws {

    }

    // check state triggers
    // reset delay if triggered
    // pause execution if triggered
    func updateSchedule(_ data: AutomationScheduleData) async throws {

    }

    
    /// helper of above
    func updateSchedules(_ datas: [AutomationScheduleData]) async {

    }

    /// delete trigger state
    func cancel(scheduleIDs: [String]) async {

    }

    /// delete trigger state
    func cancel(group: String) async {

    }


}

enum TriggerExecutionType: Equatable, Hashable {
    case execution
    case delayCancellation
}

struct TriggerResult {
    var scheduleID: String
    var triggerExecutionType: TriggerExecutionType
    var triggerInfo: TriggeringInfo
}


struct TriggerState {
    var count: UInt

    //
    var scheduleID: String

    var group: String?

    /// generate?
    var triggerID: String
}


