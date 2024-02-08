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

    func updateSchedules(
        _ datas: [AutomationScheduleData]
    ) async

    func updateScheduleState(
        scheduleID: String,
        state: AutomationScheduleState
    ) async throws

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
    
    // scheduleID to [PreparedTriggers]
    private var preparedTriggers: [String: [PreparedTrigger]] = [:]

    /// scheduleID to group
    private var scheduleGroups: [String: String] = [:]

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
        //save current app state
        self.trackStateChange(event: event)

        guard await self.isPaused == false else { return }

        var results: [PreparedTrigger.EventProcessResult] = []
        self.preparedTriggers.values
            .forEach { triggers in
                results.append(
                    contentsOf: triggers.compactMap { $0.process(event: event) }
                )
            }

        results.sort { left, right in
            left.priority < right.priority
        }

        results.forEach { result in
            if let triggerResult = result.triggerResult {
                self.continuation.yield(triggerResult)
            }
        }

        let triggerDatas = results.map { $0.triggerData }
        do {
            try await self.store.upsertTriggers(triggerDatas)
        } catch {
            AirshipLogger.error("Failed to save tigger data \(triggerDatas) error \(error)")
        }
    }
    
    /// Called once to update all schedules from the DB.
    func restoreSchedules(_ datas: [AutomationScheduleData]) async throws {
        await updateSchedules(datas)
        let activeSchedules = Set(datas.map({ $0.schedule.identifier }))
        try await self.store.deleteTriggers(excludingScheduleIDs: activeSchedules)
    }

    /// Called whenever the schedules are updated
    func updateSchedules(_ datas: [AutomationScheduleData]) async {
        /// Sort  by priority so wheen we restore the triggers we get events in order
        let sorted = datas.sorted(
            by: { l, r in
                (l.schedule.priority ?? 0) < (r.schedule.priority ?? 0)
            }
        )

        for data in sorted {
            let schedule = data.schedule

            scheduleGroups[schedule.identifier] = schedule.group

            var new: [PreparedTrigger] = []
            let old = self.preparedTriggers[data.schedule.identifier] ?? []

            for trigger in data.schedule.triggers {
                let existing = old.first(
                    where: { $0.trigger.id == trigger.id }
                )

                if let existing = existing {
                    existing.update(
                        trigger: trigger,
                        startDate: data.schedule.start,
                        endDate: data.schedule.end,
                        priority: data.schedule.priority ?? 0
                    )
                    new.append(existing)
                } else {
                    let prepared = await makePreparedTrigger(
                        schedule: data.schedule,
                        trigger: trigger,
                        type: .execution
                    )
                    new.append(prepared)
                }
            }

            for trigger in data.schedule.delay?.cancellationTriggers ?? [] {
                let existing = old.first(
                    where: { $0.trigger.id == trigger.id }
                )

                if let existing = existing {
                    existing.update(
                        trigger: trigger,
                        startDate: data.schedule.start,
                        endDate: data.schedule.end,
                        priority: data.schedule.priority ?? 0
                    )
                    new.append(existing)
                } else {
                    let prepared = await makePreparedTrigger(
                        schedule: data.schedule,
                        trigger: trigger,
                        type: .delayCancellation
                    )
                    new.append(prepared)
                }
            }

            self.preparedTriggers[schedule.identifier] = new

            let newIDs = Set(new.map { $0.trigger.id })
            let oldIDs = Set(old.map { $0.trigger.id })

            do {
                let stale = oldIDs.subtracting(newIDs)
                if !stale.isEmpty {
                    try await self.store.deleteTriggers(scheduleID: schedule.identifier, triggerIDs: stale)
                }
                
            } catch {
                AirshipLogger.error("Failed to delete trigger states error \(error)")
            }

            await self.updateScheduleState(
                scheduleID: schedule.identifier,
                state: data.scheduleState
            )
        }
    }

    /// delete trigger state
    func cancel(scheduleIDs: [String]) async {
        scheduleIDs.forEach { scheduleID in
            self.preparedTriggers.removeValue(forKey: scheduleID)
            self.scheduleGroups.removeValue(forKey: scheduleID)
        }
        
        do {
            try await self.store.deleteTriggers(scheduleIDs: scheduleIDs)
        } catch {
            AirshipLogger.error("Failed to delete trigger state \(scheduleIDs) error \(error)")
        }
    }

    /// delete trigger state
    func cancel(group: String) async {
        let scheduleIDs = self.scheduleGroups.filter { $0.value == group}.map { $0.key }
        await cancel(scheduleIDs: scheduleIDs)
    }

    private func trackStateChange(event: AutomationEvent) {
        guard case .stateChanged(let state) = event else {
            return
        }
        self.appSessionState = state
    }
    
    func updateScheduleState(scheduleID: String, state: AutomationScheduleState) async {
        switch state {
        case .idle:
            await self.activateTriggers(for: scheduleID, type: .execution)
        case .triggered, .prepared:
            await self.activateTriggers(for: scheduleID, type: .delayCancellation)
        case .paused, .finished:
            self.disableTriggers(for: scheduleID)
        default: break
        }
    }
    
    private func activateTriggers(for scheduleID: String, type: TriggerExecutionType) async {
        self.preparedTriggers[scheduleID]?.forEach { trigger in
            trigger.activate()
        }

        guard let state = self.appSessionState else { return }

        let results = self.preparedTriggers[scheduleID]?.compactMap { trigger in
            trigger.process(event: .stateChanged(state: state))
        } ?? []

        results.forEach { result in
            if let triggerResult = result.triggerResult {
                self.continuation.yield(triggerResult)
            }
        }

        let triggerDatas = results.map { $0.triggerData }

        do {
            try await self.store.upsertTriggers(triggerDatas)
        } catch {
            AirshipLogger.error("Failed to save trigger data \(triggerDatas) \(error)")
        }
    }
    
    private func disableTriggers(for scheduleID: String) {
        self.preparedTriggers[scheduleID]?.forEach { trigger in
            trigger.disable()
        }
    }

    private func emit(result: TriggerResult) async {
        guard await self.isPaused == false else { return }
        self.continuation.yield(result)
    }

    private func makePreparedTrigger(
        schedule: AutomationSchedule,
        trigger: AutomationTrigger,
        type: TriggerExecutionType
    ) async -> PreparedTrigger {
        var triggerData: TriggerData?
        do {
            triggerData = try await self.store.getTrigger(scheduleID: schedule.identifier, triggerID: trigger.id)
        } catch {
            AirshipLogger.error("Failed to load trigger state for \(trigger) error \(error)")
        }

        return PreparedTrigger(
            scheduleID: schedule.identifier,
            trigger: trigger,
            type: type,
            startDate: schedule.start,
            endDate: schedule.end,
            triggerData: triggerData,
            priority: schedule.priority ?? 0,
            date: self.date
        )
    }
}

enum TriggerExecutionType: String, Equatable, Hashable {
    case execution
    case delayCancellation = "delay_cancellation"
}

struct TriggerResult: Sendable {
    var scheduleID: String
    var triggerExecutionType: TriggerExecutionType
    var triggerInfo: TriggeringInfo
}
