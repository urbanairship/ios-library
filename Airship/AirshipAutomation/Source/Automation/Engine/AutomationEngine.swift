/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

actor AutomationEngine : AutomationEngineProtocol {
    private var startTask: Task<Void, Never>?
    private var listenerTask: Task<Void, Never>?

    nonisolated private let isEnginePaused: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)
    nonisolated private let isExecutionPaused: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)
    private let triggerQueue: AirshipSerialQueue = AirshipSerialQueue()

    private let store: AutomationStore
    private let executor: AutomationExecutor
    private let preparer: AutomationPreparer
    private let scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier
    private let eventFeed: AutomationEventFeedProtocol
    private let triggersProcessor: AutomationTriggerProcessorProtocol
    private let delayProcessor: AutomationDelayProcessorProtocol
    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper

    init(
        store: AutomationStore,
        executor: AutomationExecutor,
        preparer: AutomationPreparer,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier,
        eventFeed: AutomationEventFeedProtocol,
        triggersProcessor: AutomationTriggerProcessorProtocol,
        delayProcessor: AutomationDelayProcessorProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared
    ) {
        self.store = store
        self.executor = executor
        self.preparer = preparer
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
        self.eventFeed = eventFeed
        self.triggersProcessor = triggersProcessor
        self.delayProcessor = delayProcessor
        self.date = date
        self.taskSleeper = taskSleeper
    }

    @MainActor
    func setEnginePaused(_ paused: Bool) {
        self.isEnginePaused.set(paused)
        self.triggersProcessor.setPaused(paused)
    }

    @MainActor
    func setExecutionPaused(_ paused: Bool) {
        self.isExecutionPaused.set(paused)
    }

    func start() async {
        self.startTask = Task {
            do {
                try await self.restoreSchedules()
            } catch {
                AirshipLogger.error("Failed to restore schedules \(error)")
            }
        }

        self.listenerTask = Task {
            await self.startTask?.value

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await result in await self.triggersProcessor.triggerResults {
                        guard !Task.isCancelled else { return }
                        await self.processTriggerResult(result)
                    }
                }

                group.addTask {
                    for await event in self.eventFeed.feed {
                        guard !Task.isCancelled else { return }
                        await self.triggersProcessor.processEvent(event)
                    }
                }
            }

        }
    }

    func stop() async {
        self.startTask?.cancel()
        self.listenerTask?.cancel()
    }

    func stopSchedules(identifiers: [String]) async throws {
        AirshipLogger.debug("Stopping schedules \(identifiers)")

        await self.startTask?.value
        let now = self.date.now
        for identifier in identifiers {
            try await self.updateState(identifier: identifier) { data in
                data.schedule.end = now
                data.finished(date: now)
            }
        }
    }
		
    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        await self.startTask?.value
        let map = schedules.reduce(into: [String: AutomationSchedule]()) {
            $0[$1.identifier] = $1
        }
        
        AirshipLogger.debug("Upserting schedules \(map.keys)")

        let updated = try await store.upsertSchedules(scheduleIDs: Array(map.keys)) { [date] identifier, data in
            guard let schedule = map[identifier] else {
                throw AirshipErrors.error("Failed to upsert")
            }

            var updated = try schedule.updateOrCreate(data: data, date: self.date.now)
            updated.attempRehabilitateSchedule(date: date.now)
            return updated
        }

        await self.triggersProcessor.updateSchedules(updated)
    }

    func cancelSchedules(identifiers: [String]) async throws {
        AirshipLogger.debug("Cancelling schedules \(identifiers)")

        await self.startTask?.value
        try await store.deleteSchedules(scheduleIDs: identifiers)
        await self.triggersProcessor.cancel(scheduleIDs: identifiers)
    }

    func cancelSchedules(group: String) async throws {
        AirshipLogger.debug("Cancelling schedules with group \(group)")

        await self.startTask?.value
        try await store.deleteSchedules(group: group)
        await self.triggersProcessor.cancel(group: group)
    }

    var schedules: [AutomationSchedule] {
        get async throws {
            return try await self.store.getSchedules()
                .filter { !$0.shouldDelete(date: self.date.now) }
                .map { $0.schedule }
        }
    }

    func getSchedule(identifier: String) async throws -> AutomationSchedule? {
        guard
            let data = try await self.store.getSchedule(scheduleID: identifier),
            !data.shouldDelete(date: self.date.now)
        else {
            return nil
        }

        return data.schedule
    }

    func getSchedules(group: String) async throws -> [AutomationSchedule] {
        return try await self.store.getSchedules(group: group)
            .filter {
                !$0.shouldDelete(date: self.date.now)
            }
            .map {
                $0.schedule
            }
    }

    private func restoreSchedules() async throws {
        let now = self.date.now

        let schedules = try await self.store.getSchedules()
            .sorted { left, right in
                if (left.schedule.priority ?? 0) < (right.schedule.priority ?? 0) {
                    return true
                }

                let leftDate = left.triggerInfo?.date ?? now
                let rightDate = left.triggerInfo?.date ?? now
                return leftDate > rightDate
            }

        
        // Restore triggers
        try await self.triggersProcessor.restoreSchedules(schedules)

        // Handle interrupted
        let interrupted = schedules.filter {
            $0.isInState([.executing, .prepared, .triggered])
        }

        for data in interrupted {
            var updated: AutomationScheduleData?

            if data.scheduleState == .executing, let preparedInfo = data.preparedScheduleInfo {
                let behavior = await self.executor.interrupted(schedule: data.schedule, preparedScheduleInfo: preparedInfo)

                updated = try await self.updateState(identifier: data.schedule.identifier) {  data in
                    data.executionInterrupted(date: now, retry: behavior == .retry)
                }
            } else {
                updated = try await self.updateState(identifier: data.schedule.identifier) {  data in
                    data.prepareInterrupted(date: now)
                }
            }

            if (updated?.scheduleState == .triggered) {
                await startTaskToProcessTriggeredSchedule(scheduleID: data.schedule.identifier)
            }
        }

        // Restore Intervals
        let paused = schedules.filter { $0.scheduleState == .paused }
        for data in paused {
            let interval = data.schedule.interval ?? 0.0
            let remaining = interval - self.date.now.timeIntervalSince(data.scheduleStateChangeDate)
            handleInterval(remaining, scheduleID: data.schedule.identifier)
        }

        /// Delete finished schedules
        let shouldDelete = schedules
            .filter { $0.shouldDelete(date: now) }
            .map { $0.schedule.identifier }

        if !shouldDelete.isEmpty {
            try await self.store.deleteSchedules(scheduleIDs: shouldDelete)
            await self.triggersProcessor.cancel(scheduleIDs: shouldDelete)
        }
    }

    private func handleInterval(_ interval: TimeInterval, scheduleID: String) {
        Task { [weak self, date] in
            try await self?.taskSleeper.sleep(timeInterval: interval)
            try await self?.updateState(identifier: scheduleID) { data in
                data.idle(date: date.now)
            }
        }
    }
}


/// Schedule processing
fileprivate extension AutomationEngine {
    private func processTriggerResult(_ result: TriggerResult) async {
        let now = self.date.now
        await self.triggerQueue.runSafe {
            do {
                switch (result.triggerExecutionType) {
                case .delayCancellation:
                    let updated = try await self.updateState(identifier: result.scheduleID) { data in
                        data.prepareCancelled(date: now)
                    }

                    if let updated = updated {
                        await self.preparer.cancelled(schedule: updated.schedule)
                    }
                    break

                case .execution:
                    try await self.updateState(identifier: result.scheduleID) { data in
                        data.triggered(triggerContext: result.triggerInfo.context, date: now)
                    }

                    await self.startTaskToProcessTriggeredSchedule(
                        scheduleID: result.scheduleID
                    )
                }
            } catch {
                AirshipLogger.error("Failed to process trigger result: \(result), error: \(error)")
            }
        }
    }

    private func startTaskToProcessTriggeredSchedule(scheduleID: String) async {
        AirshipLogger.trace("Starting task to process schedule \(scheduleID)")

        // pause the current contex
        await withUnsafeContinuation { continuation in
            Task {
                // actor context
                continuation.resume()
                do {
                    AirshipLogger.trace("Processing triggered schedule \(scheduleID)")
                    try await self.processTriggeredSchedule(scheduleID: scheduleID)
                } catch {
                    AirshipLogger.error("Failed to process triggered schedule \(scheduleID) error: \(error)")
                }
            }
        }
    }


    private func processTriggeredSchedule(scheduleID: String) async throws {
        /// Using a while loop to retry prepared schedule if fails
        while true {
            guard
                let data = try await self.store.getSchedule(scheduleID: scheduleID),
                data.isInState([.triggered])
            else {
                AirshipLogger.trace("Aborting processing schedule \(scheduleID), no longer triggered.")
                return
            }

            guard data.isActive(date: self.date.now) else {
                AirshipLogger.trace("Aborting processing schedule \(scheduleID), no longer active.")
                await self.preparer.cancelled(schedule: data.schedule)
                return
            }

            /// Prepare
            guard let preparedSchedule = try await self.prepareSchedule(data: data) else {
                return
            }

            // Execute
            try await self.startExecuting(data: data, preparedSchedule: preparedSchedule)
        }
    }

    private func prepareSchedule(data: AutomationScheduleData) async throws -> PreparedSchedule? {
        AirshipLogger.trace("Preparing schedule \(data)")

        let prepareResult = await self.preparer.prepare(
            schedule: data.schedule,
            triggerContext: data.triggerInfo?.context
        )

        AirshipLogger.trace("Preparing schedule \(data) result: \(prepareResult)")
        if case .cancel = prepareResult {
            try await self.store.deleteSchedules(scheduleIDs: [data.schedule.identifier])
            return nil
        }

        try await self.updateState(identifier: data.schedule.identifier) { [date] data in
            guard data.isInState([.triggered]) else { return }

            switch (prepareResult) {
            case .prepared(let preparedSchedule):
                data.prepared(info: preparedSchedule.info, date: date.now)
            case .invalidate, .cancel:
               break
            case .skip:
                data.prepareSkipped(date: date.now, penalize: false)
            case .penalize:
                data.prepareSkipped(date: date.now, penalize: true)
            }
        }

        switch prepareResult {
        case .prepared(let info): 
            return info
        case .invalidate:
            await self.startTaskToProcessTriggeredSchedule(
                scheduleID: data.schedule.identifier
            )
            return nil
        case .cancel, .skip, .penalize:
            return nil
        }
    }

    @MainActor
    private func startExecuting(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) async throws {
        AirshipLogger.trace("Starting to execute schedule \(data)")

        let scheduleID = data.schedule.identifier

        // Using a while loop to recheck conditions on `notReady` results
        while true {
            let readyResult = try await self.checkReady(data: data, preparedSchedule: preparedSchedule)
            switch (readyResult) {
            case .ready:
                break

            case .invalidate:
                let updated = try await self.updateState(identifier: scheduleID) { [date] data in
                    data.executionInvalidated(date: date.now)
                }

                if updated?.scheduleState == .triggered {
                    await self.startTaskToProcessTriggeredSchedule(
                        scheduleID: data.schedule.identifier
                    )
                }
                return

            case .notReady:
                await self.scheduleConditionsChangedNotifier.wait()
                continue

            case .skip:
                try await self.updateState(identifier: scheduleID) { [date] data in
                    data.executionSkipped(date: date.now)
                }
                return
            }


            let executeResult = try await self.execute(preparedSchedule: preparedSchedule)

            switch (executeResult) {
            case .cancel:
                try await self.store.deleteSchedules(scheduleIDs: [scheduleID])
                await self.triggersProcessor.cancel(scheduleIDs: [scheduleID])

            case .finished:
                let updated = try await self.updateState(identifier: scheduleID) {  [date] data in
                    data.finishedExecuting(date: date.now)
                }

                if let updated = updated, updated.scheduleState == .paused {
                    await handleInterval(updated.schedule.interval ?? 0.0, scheduleID: updated.schedule.identifier)
                }

            case .retry:
                continue
            }

            return
        }
    }

    @MainActor
    private func execute(preparedSchedule: PreparedSchedule) async throws -> ScheduleExecuteResult {
        AirshipLogger.trace("Executiong schedule \(preparedSchedule.info.scheduleID)")

        // Execute
        let updateStateTask = Task {
            try await self.updateState(identifier: preparedSchedule.info.scheduleID) { [date] data in
                data.executing(date: date.now)
            }
        }

        let executeResult = await self.executor.execute(preparedSchedule: preparedSchedule)

        _ = try await updateStateTask.value

        AirshipLogger.trace("Executiong result \(preparedSchedule.info.scheduleID) \(executeResult)")

        return executeResult
    }

    @MainActor
    private func checkReady(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) async throws -> ScheduleReadyResult {
        AirshipLogger.trace("Checking if schedule is ready \(data)")

        let triggerDate = data.triggerInfo?.date ?? data.scheduleStateChangeDate

        // Wait for conditions
        AirshipLogger.trace("Waiting for delay conditions \(data)")
        await self.delayProcessor.process(
            delay: data.schedule.delay,
            triggerDate: triggerDate
        )

        AirshipLogger.trace("Delay conditions met \(data)")


        // Make sure we are still up to date. Data might change due to a change
        // in the data, schedule was cancelled, or if a delay cancellation trigger
        // was fired.
        guard
            let fromStore = try? await self.store.getSchedule(scheduleID: data.schedule.identifier),
            fromStore.scheduleState == .prepared,
            fromStore.schedule == data.schedule
        else {
            AirshipLogger.trace("Schedule no longer valid, invalidating \(data)")
            return .invalidate
        }

        // Precheck
        let precheckResult = await self.executor.isReadyPrecheck(
            schedule: data.schedule
        )

        guard precheckResult == .ready else {
            AirshipLogger.trace("Precheck not ready \(data)")
            return precheckResult
        }

        // Verify conditions still met
        guard
            self.delayProcessor.areConditionsMet(delay: data.schedule.delay)
        else {
            AirshipLogger.trace("Delay conditions not met, not ready \(data)")
            return .notReady
        }

        guard !self.isExecutionPaused.value, !self.isEnginePaused.value else {
            AirshipLogger.trace("Executor paused, not ready \(data)")
            return .notReady
        }

        guard data.isActive(date: self.date.now) else {
            AirshipLogger.trace("Schedule no longer active, Invalidating \(data)")
            return .invalidate
        }

        let result = self.executor.isReady(preparedSchedule: preparedSchedule)
        if result != .ready {
            AirshipLogger.trace("Schedule not ready \(data)")
        }
        return result
    }

    @discardableResult
    func updateState(
        identifier: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        let updated = try await self.store.updateSchedule(scheduleID: identifier, block: block)
        if let updated = updated {
            try await self.triggersProcessor.updateScheduleState(
                scheduleID: identifier,
                state: updated.scheduleState
            )
        }
        return updated
    }
}

fileprivate extension AutomationSchedule {
    func updateOrCreate(data: AutomationScheduleData?, date: Date) throws -> AutomationScheduleData {
        guard var existing = data else {
            return AutomationScheduleData(
                schedule: self,
                scheduleState: .idle,
                scheduleStateChangeDate: date
            )
        }

        existing.schedule = self
        return existing
    }
}


/// Automation engine
protocol AutomationEngineProtocol: AnyActor, Sendable {
    @MainActor
    func setEnginePaused(_ paused: Bool)

    @MainActor
    func setExecutionPaused(_ paused: Bool)
    func start() async

    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws

    func stopSchedules(identifiers: [String]) async throws
    func cancelSchedules(identifiers: [String]) async throws
    func cancelSchedules(group: String) async throws

    var schedules: [AutomationSchedule] { get async throws }
    func getSchedule(identifier: String) async throws -> AutomationSchedule?
    func getSchedules(group: String) async throws -> [AutomationSchedule]
}
