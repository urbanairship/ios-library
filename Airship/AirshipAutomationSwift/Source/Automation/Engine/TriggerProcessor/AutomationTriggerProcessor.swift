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

final actor AutomationTriggerProcessor: AutomationTriggerProcessorProtocol {
    let store: TriggerStoreProtocol
    private let date: AirshipDateProtocol
    private let stream: AsyncStream<TriggerResult>
    private let continuation: AsyncStream<TriggerResult>.Continuation
    
    @MainActor private var isPaused = false
    
    private var preparedTriggers: [PreparedTrigger] = []
    private var appSessionState: TriggerableState?
    
    init(
        store: TriggerStoreProtocol,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.store = store
        self.date = date
        (self.stream, self.continuation) = AsyncStream<TriggerResult>.airshipMakeStreamWithContinuation()
    }

    @MainActor
    func setPaused(_ paused: Bool) {
        self.isPaused = paused
    }

    var triggerResults: AsyncStream<TriggerResult> {
        return self.stream
    }

    // check triggers for events
    func processEvent(_ event: AutomationEvent) async {
        guard await self.isPaused == false else { return }
        
        //save current state
        self.trackStateChange(event: event)
        
        var stateUpdates: [TriggerState] = []
        
        for trigger in self.preparedTriggers {
            guard 
                trigger.isActive,
                let (state, result) = trigger.process(event: event)
            else { continue }
            
            stateUpdates.append(state)
            if let result = result {
                self.continuation.yield(result)
            }
        }
        
        try? await self.store.saveTriggerStates(states: stateUpdates)
    }
    
    // check state triggers
    func restoreSchedules(_ datas: [AutomationScheduleData]) async throws {
        var activeTriggers: [PreparedTrigger] = []
        for data in datas {
            let schedule = data.schedule
            
            //prepare execution triggers
            for trigger in data.schedule.triggers {
                let state = try? await self.store.savedTriggerState(triggerID: trigger.id)
                
                let prepared = PreparedTrigger(
                    scheduleID: schedule.identifier,
                    group: schedule.group,
                    trigger: trigger,
                    type: .execution,
                    startDate: schedule.start,
                    endDate: schedule.end,
                    date: self.date,
                    state: state)
                
                activeTriggers.append(prepared)
            }
            
            //prepare cancellation triggers
            if let cancellation = data.schedule.delay?.cancellationTriggers {
                for trigger in cancellation {
                    let state = try? await self.store.savedTriggerState(triggerID: trigger.id)
                    
                    let prepared = PreparedTrigger(
                        scheduleID: schedule.identifier,
                        group: schedule.group,
                        trigger: trigger,
                        type: .delayCancellation,
                        startDate: schedule.start,
                        endDate: schedule.end,
                        date: self.date,
                        state: state)
                    
                    activeTriggers.append(prepared)
                }
            }
        }
        
        self.preparedTriggers = activeTriggers
        let activeSchedules = Set(activeTriggers.map({ $0.scheduleID }))
        
        try? await self.store.removeAllTriggerStates(excluding: activeSchedules)
        await self.startProcessingTriggers(for: datas)
    }

    // check state triggers
    // reset delay if triggered
    // pause execution if triggered
    func updateSchedule(_ data: AutomationScheduleData) async throws {
        
        let schedule = data.schedule
        
        //execution triggers update
        for trigger in schedule.triggers {
            guard let prepared = self.preparedTriggers.first(where: { $0.trigger.id == trigger.id }) else { continue }
            prepared.udpateSchedule(startDate: schedule.start, endDate: schedule.end)
        }
        
        //cancellation triggers update
        if let triggers = data.schedule.delay?.cancellationTriggers {
            for trigger in triggers {
                guard let prepared = self.preparedTriggers.first(where: { $0.trigger.id == trigger.id }) else { continue }
                prepared.udpateSchedule(startDate: schedule.start, endDate: schedule.end)
            }
        }
        
        await self.startProcessingTriggers(for: [data])
    }
    
    /// helper of above
    func updateSchedules(_ datas: [AutomationScheduleData]) async {
        for data in datas {
            do {
                try await updateSchedule(data)
            } catch {
                AirshipLogger.error("Failed to updated schedule \(data) \(error)")
            }
        }
    }

    /// delete trigger state
    func cancel(scheduleIDs: [String]) async {
        preparedTriggers.removeAll(where: { scheduleIDs.contains($0.scheduleID) })
        try? await self.store.removeTriggerStatesFor(scheduleIDs: scheduleIDs)
    }

    /// delete trigger state
    func cancel(group: String) async {
        preparedTriggers.removeAll(where: { $0.group == group })
        try? await self.store.removeTriggerStateFor(group: group)
    }
    
    private func trackStateChange(event: AutomationEvent) {
        switch event {
        case .stateChanged(let state):
            self.appSessionState = state
        default: break
        }
    }
    
    private func startProcessingTriggers(for datas: [AutomationScheduleData]) async {
        for data in datas {
            let schedule = data.schedule
            
            switch data.scheduleState {
            case .idle:
                await self.activateTriggers(for: schedule.identifier, type: .execution)
            case .triggered, .prepared:
                await self.activateTriggers(for: schedule.identifier, type: .delayCancellation)
            case .paused, .finished:
                self.disableTriggers(for: schedule.identifier)
            default: break
            }
        }
    }
    
    private func activateTriggers(for scheduleID: String, type: TriggerExecutionType) async {
        
        var stateUpdates: [TriggerState] = []
        for trigger in self.preparedTriggers {
            guard trigger.scheduleID == scheduleID, trigger.executionType == type else {
                continue
            }
            
            trigger.activate()
            
            guard let state = self.appSessionState else { continue }
            
            if let (updatedState, result) = trigger.process(event: .stateChanged(state: state)) {
                stateUpdates.append(updatedState)
                if let result = result {
                    self.continuation.yield(result)
                }
            }
        }
        
        try? await self.store.saveTriggerStates(states: stateUpdates)
    }
    
    private func disableTriggers(for scheduleID: String) {
        self.preparedTriggers
            .filter({ $0.scheduleID == scheduleID })
            .forEach({ $0.disable() })
    }

    private func emit(result: TriggerResult) async {
        guard await self.isPaused == false else { return }
        self.continuation.yield(result)
    }
}

enum TriggerExecutionType: Equatable, Hashable {
    case execution
    case delayCancellation
}

struct TriggerResult: Sendable {
    var scheduleID: String
    var triggerExecutionType: TriggerExecutionType
    var triggerInfo: TriggeringInfo
}

struct TriggerState: Sendable, Equatable {
    var count: Double
    
    var goal: Double

    var scheduleID: String

    var group: String?

    var triggerID: String
    
    var children: [TriggerState]
    
    var isGoalReached: Bool { return count >= goal && children.allSatisfy({ $0.isGoalReached }) }
    
    func incremented(with value: Double) -> TriggerState {
        return TriggerState(
            count: self.count + value,
            goal: self.goal,
            scheduleID: self.scheduleID,
            group: self.group,
            triggerID: self.triggerID,
            children: self.children
        )
    }
    
    mutating func reset() {
        self.count = 0
    }
}
