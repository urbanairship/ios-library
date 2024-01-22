/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationTriggerProcessorProtocol: AnyActor {
    func processEvent(_ event: AutomationEvent) async -> [TriggerResult]
    func updateTriggers(scheduleID: String, triggers: [AutomationTrigger]) async
    func setActiveTriggerType(scheduleID: String, type: ActiveTriggerType)
}

enum ActiveTriggerType {
    case execution
    case delayCancellation
    case cancellation
}

struct TriggerResult {
    var scheduleID: String
    var activeTriggerType: ActiveTriggerType
    var triggerInfo: TriggeringInfo
}

