/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

// This is only called from an actor `AutomationTriggerProcessor`
final class PreparedTrigger {
    struct EventProcessResult {
        var triggerData: TriggerData
        var triggerResult: TriggerResult?
        var priority: Int
    }

    let date: AirshipDateProtocol
    let scheduleID: String
    let executionType: TriggerExecutionType

    private(set) var triggerData: TriggerData
    private(set) var trigger: AutomationTrigger
    private(set) var isActive: Bool = false
    private(set) var startDate: Date?
    private(set) var endDate: Date?
    private(set) var priority: Int

    init(
        scheduleID: String,
        trigger: AutomationTrigger,
        type: TriggerExecutionType,
        startDate: Date?,
        endDate: Date?,
        triggerData: TriggerData?,
        priority: Int,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.scheduleID = scheduleID
        self.executionType = type
        self.date = date
        self.trigger = trigger
        self.startDate = startDate
        self.endDate = endDate

        self.triggerData = triggerData ?? TriggerData(
            scheduleID: scheduleID,
            triggerID: trigger.id
        )

        self.priority = priority
        self.trigger.removeStaleChildData(data: &self.triggerData)
    }
    
    func process(event: AutomationEvent) -> EventProcessResult? {
        guard self.isActive, self.isWithingDateRange() else {
            return nil
        }

        var currentData = self.triggerData
        let match = self.trigger.matchEvent(event, data: &currentData, resetOnTrigger: true)

        guard currentData != self.triggerData || match?.isTriggered == true else {
            return nil
        }

        self.triggerData = currentData

        return EventProcessResult(
            triggerData: triggerData,
            triggerResult: match?.isTriggered == true ? generateTriggerResult(for: event) : nil,
            priority: self.priority
        )
    }
    
    func update(
        trigger: AutomationTrigger,
        startDate: Date?,
        endDate: Date?,
        priority: Int
    ) {
        self.trigger = trigger
        self.startDate = startDate
        self.endDate = endDate
        self.priority = priority
        self.trigger.removeStaleChildData(data: &triggerData)
    }
    
    func activate() {
        guard !self.isActive else { return }
        
        self.isActive = true

        if self.executionType == .delayCancellation {
            self.triggerData.resetCount()
        }
    }
    
    func disable() {
        self.isActive = false
    }
    
    private func generateTriggerResult(for event: AutomationEvent) -> TriggerResult {
        return TriggerResult(
            scheduleID: self.scheduleID,
            triggerExecutionType: self.executionType,
            triggerInfo: TriggeringInfo(
                context: AirshipTriggerContext(
                    type: trigger.type,
                    goal: trigger.goal,
                    event: event.reportPayload() ?? AirshipJSON.null),
                date: self.date.now
            )
        )
    }

    private func isWithingDateRange() -> Bool {
        let now = self.date.now
        if let start = self.startDate, start > now {
            return false
        }

        if let end = self.endDate, end < now {
            return false
        }

        return true
    }
}

extension TriggerData {
    func childData(triggerID: String) -> TriggerData {
        guard let data = self.children[triggerID] else {
            return TriggerData(scheduleID: self.scheduleID, triggerID: triggerID, count: 0)
        }
        return data
    }
}

extension EventAutomationTrigger {
    fileprivate func matchEvent(_ event: AutomationEvent, data: inout TriggerData) -> MatchResult? {
        switch event {
        case .stateChanged(let state):
            return stateTriggerMatch(state: state, data: &data)
        case .foreground:
            guard self.type == .foreground else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .background:
            guard self.type == .background else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .appInit:
            guard self.type == .appInit else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .screenView(let name):
            guard self.type == .screen, isPredicateMatching(value: name) else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .regionEnter(let eventData):
            guard self.type == .regionEnter, isPredicateMatching(value: eventData) else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .regionExit(let eventData):
            guard self.type == .regionExit, isPredicateMatching(value: eventData) else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .customEvent(let eventData, let value):
            return customEvenTriggerMatch(eventData: eventData, value: value, data: &data)
        case .featureFlagInterracted(let eventData):
            guard self.type == .featureFlagInteraction, isPredicateMatching(value: eventData) else { return nil }
            return evaluateResults(data: &data, increment: 1)
        }
    }

    private func stateTriggerMatch(state: TriggerableState, data: inout TriggerData) -> MatchResult? {
        switch self.type {
        case .version:
            guard
                let versionUpdated = state.versionUpdated,
                versionUpdated != data.lastTriggerableState?.versionUpdated,
                isPredicateMatching(value: versionUpdated)
            else {
                return nil
            }

            data.lastTriggerableState = state
            return evaluateResults(data: &data, increment: 1)
        case .activeSession:
            guard
                let appSessionID = state.appSessionID,
                    appSessionID != data.lastTriggerableState?.appSessionID
            else {
                return nil
            }

            data.lastTriggerableState = state
            return evaluateResults(data: &data, increment: 1)
        default:
           return nil
        }
    }

    private func customEvenTriggerMatch(eventData: AirshipJSON, value: Double?, data: inout TriggerData) -> MatchResult? {
        switch self.type {
        case .customEventCount:
            guard isPredicateMatching(value: eventData.unWrap()) else { return nil }
            return evaluateResults(data: &data, increment: 1)
        case .customEventValue:
            guard isPredicateMatching(value: eventData.unWrap()) else { return nil }
            return evaluateResults(data: &data, increment: value ?? 1.0)
        default:
            return nil
        }
    }

    private func isPredicateMatching(value: Any?) -> Bool {
        guard let predicate = self.predicate else { return true }
        return predicate.evaluate(value)
    }

    private func evaluateResults(
        data: inout TriggerData,
        increment: Double
    ) -> MatchResult {
        data.incrementCount(increment)
        return MatchResult(
            triggerID: self.id,
            isTriggered: data.count >= self.goal
        )
    }
}

extension CompoundAutomationTrigger {
    fileprivate func matchEvent(_ event: AutomationEvent, data: inout TriggerData) -> MatchResult? {

        let childResults = self.matchChildren(event: event, data: &data)

        switch self.type {
        case .and, .chain:
            let shouldIncrement = childResults.allSatisfy { result in
                result.isTriggered
            }

            if (shouldIncrement) {
                self.children.forEach { child in
                    // Only reset the child if its not sticky
                    if child.isSticky != true {
                        var childData = data.childData(triggerID: child.trigger.id)
                        childData.resetCount()
                        data.children[child.trigger.id] = childData
                    }
                }
                data.incrementCount(1.0)
            }

        case .or:
            let shouldIncrement = childResults.contains(
                where: { result in result.isTriggered }
            )

            if (shouldIncrement) {
                self.children.forEach { child in
                    var childData = data.childData(triggerID: child.trigger.id)

                    // Reset the child if it reached the goal or if we are resetting it
                    // on increment
                    if (childData.count >= child.trigger.goal || child.resetOnIncrement == true) {
                        childData.resetCount()
                    }

                    data.children[child.trigger.id] = childData
                }
                data.incrementCount(1.0)
            }
        }

        return MatchResult(triggerID: self.id, isTriggered: data.count >= self.goal)
    }

    private func matchChildren(
        event: AutomationEvent,
        data: inout TriggerData
    ) -> [MatchResult] {
        var evaluateRemaining = true
        return children.map { child in
            var childData = data.childData(triggerID: child.trigger.id)

            var matchResult: MatchResult?
            if evaluateRemaining {
                // Match the child without resetting it on trigger. We will process resets
                // after we get all the child results
                matchResult = child.trigger.matchEvent(event, data: &childData, resetOnTrigger: false)
            }

            let result = matchResult ?? MatchResult(
                triggerID: child.trigger.id,
                isTriggered: child.trigger.isTriggered(data: childData)
            )

            if self.type == .chain, evaluateRemaining, !result.isTriggered {
                evaluateRemaining = false
            }

            data.children[child.trigger.id] = childData
            return result
        }
    }

    func removeStaleChildData(data: inout TriggerData) {
        guard data.children.isEmpty else { return }

        var updatedData: [String: TriggerData] = [:]

        self.children.forEach { child in
            var childData = data.childData(triggerID: child.trigger.id)
            child.trigger.removeStaleChildData(data: &childData)
            updatedData[child.trigger.id] = childData
        }

        data.children = updatedData
    }
}

extension AutomationTrigger {

    fileprivate func matchEvent(
        _ event: AutomationEvent,
        data: inout TriggerData,
        resetOnTrigger: Bool
    ) -> MatchResult? {

        let result: MatchResult? = switch self {
        case .compound(let compoundTrigger):
            compoundTrigger.matchEvent(event, data: &data)
        case .event(let eventTrigger):
            eventTrigger.matchEvent(event, data: &data)
        }

        if resetOnTrigger, result?.isTriggered == true {
            data.resetCount()
        }

        return result
    }

    func isTriggered(data: TriggerData) -> Bool {
        return data.count >= self.goal
    }


    func removeStaleChildData(data: inout TriggerData) {
        guard case .compound(let compoundTrigger) = self else {
            return
        }

        compoundTrigger.removeStaleChildData(data: &data)
    }
}

fileprivate struct MatchResult {
   var triggerID: String
   var isTriggered: Bool
}
