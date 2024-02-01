/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

final class PreparedTrigger: @unchecked Sendable {
    typealias EventProcessResult = (newState: TriggerState, result: TriggerResult?)
    private typealias MatchTuple = (isMatched: Bool, incrementAmount: Double)
    
    private let lock = AirshipLock()
    
    let date: AirshipDateProtocol
    let scheduleID: String
    let group: String?
    let executionType: TriggerExecutionType
    let trigger: AutomationTrigger
    
    private var _state: TriggerState
    private(set) var state: TriggerState {
        get { return lock.sync { _state } }
        set { lock.sync { _state = newValue } }
    }
    
    private var _appState: TriggerableState?
    private(set) var appState: TriggerableState? {
        get { return lock.sync { _appState } }
        set { return lock.sync { _appState = newValue } }
    }
    
    private var _isActive: Bool = false
    private(set) var isActive: Bool {
        get { lock.sync { _isActive } }
        set { lock.sync { _isActive = newValue } }
    }
    
    private var _startDate: Date?
    private(set) var startDate: Date? {
        get { return lock.sync { _startDate } }
        set { return lock.sync { _startDate = newValue } }
    }
    
    private var _endDate: Date?
    private(set) var endDate: Date? {
        get { return lock.sync { _endDate } }
        set { return lock.sync { _endDate = newValue } }
    }
    
    init(
        scheduleID: String,
        group: String?,
        trigger: AutomationTrigger,
        type: TriggerExecutionType,
        startDate: Date?,
        endDate: Date?,
        date: AirshipDateProtocol = AirshipDate.shared,
        state: TriggerState?
    ) {
        self.scheduleID = scheduleID
        self.group = group
        self.trigger = trigger
        self.executionType = type
        self.date = date
        
        _startDate = startDate
        _endDate = endDate
        
        _state = state ?? TriggerState(
            count: 0,
            goal: trigger.goal,
            scheduleID: scheduleID,
            group: group,
            triggerID: trigger.id,
            children: [] // for compound triggers
        )
    }
    
    func process(event: AutomationEvent) -> EventProcessResult? {
        guard  self.isActive, self.isWithingDateRange() else { return nil }
        
        let (isAffected, amount) = self.isMatchig(event: event)
        if !isAffected {
            return nil
        }
        
        self.state = self.state.incremented(with: amount)
        
        //report state changes but the goal is not reached
        if !state.isGoalReached {
            return (state, nil)
        }
        
        self.state.reset()
        
        return (state, generateTriggerResult(for: event))
    }
    
    func udpateSchedule(startDate: Date? = nil, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    func activate() {
        guard !self.isActive else { return }
        
        self.appState = nil
        self.isActive = true
        
        if self.executionType == .delayCancellation {
            self.state.reset()
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
                    type: trigger.type.rawValue,
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
    
    private func isMatchig(event: AutomationEvent) -> MatchTuple {
        switch event {
        case .stateChanged(let state):
            if state == self.appState {
                return matchResult(isMatched: false)
            }
            
            return onNewAppState(newState: state)
        case .foreground:
            return matchResult(isMatched: self.trigger.type == .foreground)
        case .background:
            return matchResult(isMatched: self.trigger.type == .background)
        case .appInit:
            return matchResult(isMatched: self.trigger.type == .appInit)
        case .screenView(let name):
            if self.trigger.type != .screen { return matchResult(isMatched: false) }
            return isPredicateMatching(value: name)
        case .regionEnter(let regionId):
            if self.trigger.type != .regionEnter { return matchResult(isMatched: false) }
            return isPredicateMatching(value: regionId)
        case .regionExit(let regionId):
            if self.trigger.type != .regionExit { return matchResult(isMatched: false) }
            return isPredicateMatching(value: regionId)
        case .customEvent(let data, let value):
            return customEventMatch(data: data, value: value)
        case .featureFlagInterracted(let data):
            if self.trigger.type != .featureFlagInteraction { return matchResult(isMatched: false) }
            return isPredicateMatching(value: data)
        }
    }
    
    private func onNewAppState(newState: TriggerableState) -> MatchTuple {
        let result: MatchTuple
        
        switch trigger.type {
        case .version:
            if newState.versionUpdated == nil || newState.versionUpdated == self.appState?.versionUpdated {
                result = matchResult(isMatched: false)
            } else {
                result = isPredicateMatching(value: newState.versionUpdated)
            }
        case .activeSession:
            result = matchResult(isMatched: newState.appSessionID != nil && newState.appSessionID != self.appState?.appSessionID)
        default:
            result = matchResult(isMatched: false)
        }
        
        self.appState = newState
        return result
    }
    
    private func customEventMatch(data: AirshipJSON, value: Double?) -> MatchTuple {
        if self.trigger.type == .customEventCount {
            return isPredicateMatching(value: data)
        } else if self.trigger.type == .customEventValue, let value = value {
            return isPredicateMatching(value: data, increment: value)
        } else {
            return matchResult(isMatched: false)
        }
    }
    
    private func isPredicateMatching(value: Any?, increment: Double = 1) -> MatchTuple {
        guard let predicate = self.trigger.predicate else { return matchResult(isMatched: true, increment: increment) }
        
        return matchResult(isMatched: predicate.evaluate(value), increment: increment)
    }
    
    private func matchResult(isMatched: Bool, increment: Double = 1) -> MatchTuple {
        return (isMatched, increment)
    }
}
