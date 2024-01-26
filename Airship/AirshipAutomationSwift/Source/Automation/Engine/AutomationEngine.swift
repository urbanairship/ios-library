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
    private let conditionsMonitor: AutomationConditionsMonitorProtocol
    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper

    init(
        store: AutomationStore,
        executor: AutomationExecutor,
        preparer: AutomationPreparer,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier,
        eventFeed: AutomationEventFeedProtocol,
        triggersProcessor: AutomationTriggerProcessorProtocol,
        conditionsMonitor: AutomationConditionsMonitorProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = .shared
    ) {
        self.store = store
        self.executor = executor
        self.preparer = preparer
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
        self.eventFeed = eventFeed
        self.triggersProcessor = triggersProcessor
        self.conditionsMonitor = conditionsMonitor
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
        await self.startTask?.value
        let now = self.date.now
        for identifier in identifiers {
            try await self.updateDataAndTriggers(identifier: identifier) { data in
                data.endDate = now
                data.finished(date: now)
            }
        }
    }
		
    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        await self.startTask?.value
        let map = schedules.reduce(into: [String: AutomationSchedule]()) {
            $0[$1.identifier] = $1
        }
        
        let updated = try await store.batchUpsert(identifiers: Array(map.keys)) { [date] identifier, data in
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
        await self.startTask?.value
        try await store.delete(identifiers: identifiers)
        await self.triggersProcessor.cancel(scheduleIDs: identifiers)
    }

    func cancelSchedules(group: String) async throws {
        await self.startTask?.value
        try await store.delete(group: group)
        await self.triggersProcessor.cancel(group: group)
    }

    var schedules: [AutomationSchedule] {
        get async throws {
            return try await self.store.schedules
                .filter {
                    !$0.shouldDelete(date: self.date.now)
                }
                .map {
                    $0.schedule
                }
        }
    }

    func getSchedule(identifier: String) async throws -> AutomationSchedule? {
        guard
            let data = try await self.store.getSchedule(identifier: identifier),
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

        let schedules = try await self.store.schedules
            .sorted { left, right in
                if (left.schedule.priority ?? 0) > (right.schedule.priority ?? 0) {
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

                updated = try await self.updateDataAndTriggers(identifier: data.identifier) {  data in
                    data.executionInterrupted(date: now, retry: behavior == .retry)
                }
            } else {
                updated = try await self.updateDataAndTriggers(identifier: data.identifier) {  data in
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
            .map { $0.identifier }

        if !shouldDelete.isEmpty {
            try await self.store.delete(identifiers: shouldDelete)
            await self.triggersProcessor.cancel(scheduleIDs: shouldDelete)
        }
    }

    private func handleInterval(_ interval: TimeInterval, scheduleID: String) {
        Task { [weak self, date] in
            try await self?.taskSleeper.sleep(timeInterval: interval)
            try await self?.updateDataAndTriggers(identifier: scheduleID) { data in
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
                    let updated = try await self.updateDataAndTriggers(identifier: result.scheduleID) { data in
                        data.prepareCancelled(date: now)
                    }

                    if let updated = updated {
                        await self.preparer.cancelled(schedule: updated.schedule)
                    }
                    break

                case .execution:
                    try await self.updateDataAndTriggers(identifier: result.scheduleID) { data in
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
        // pause the current contex
        await withUnsafeContinuation { continuation in
            Task {
                // actor context
                continuation.resume()
                do {
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
                let data = try await self.store.getSchedule(identifier: scheduleID), data.isInState([.triggered])
            else {
                return
            }

            guard data.isActive(date: self.date.now) else {
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
        let prepareResult = await self.preparer.prepare(
            schedule: data.schedule,
            triggerContext: data.triggerInfo?.context
        )

        if case .cancel = prepareResult {
            try await self.store.delete(identifiers: [data.identifier])
            return nil
        }

        try await self.updateDataAndTriggers(identifier: data.identifier) { [date] data in
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
        case .prepared(let info): return info
        case .invalidate:
            await self.startTaskToProcessTriggeredSchedule(
                scheduleID: data.schedule.identifier
            )
            return nil
        case .cancel, .skip, .penalize: return nil
        }
    }

    @MainActor
    private func startExecuting(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) async throws {
        let scheduleID = data.schedule.identifier

        // Using a while loop to recheck conditions on `notReady` results
        while true {
            let readyResult = try await self.checkReady(data: data, preparedSchedule: preparedSchedule)
            switch (readyResult) {
            case .ready: 
                break

            case .invalidate:
                try await self.updateDataAndTriggers(identifier: scheduleID) { [date] data in
                    data.executionInvalidated(date: date.now)
                }

                await self.startTaskToProcessTriggeredSchedule(
                    scheduleID: data.schedule.identifier
                )
                return

            case .notReady:
                await self.scheduleConditionsChangedNotifier.wait()
                continue

            case .skip:
                try await self.updateDataAndTriggers(identifier: scheduleID) { [date] data in
                    data.executionSkipped(date: date.now)
                }
                return
            }

            let executeResult = try await self.execute(preparedSchedule: preparedSchedule)
            switch (executeResult) {
            case .cancel:
                try await self.store.delete(identifiers: [scheduleID])
                await self.triggersProcessor.cancel(scheduleIDs: [scheduleID])

            case .finished:
                let updated = try await self.updateDataAndTriggers(identifier: scheduleID) {  [date] data in
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
        // Execute
        let updateStateTask = Task {
            try await self.updateDataAndTriggers(identifier: preparedSchedule.info.scheduleID) { [date] data in
                data.executing(date: date.now)
            }
        }

        let executeResult = await self.executor.execute(preparedSchedule: preparedSchedule)

        _ = try await updateStateTask.value

        return executeResult
    }

    @MainActor
    private func checkReady(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) async throws -> ScheduleReadyResult {
        // Wait for conditions
        await self.conditionsMonitor.wait(
            delay: data.schedule.delay,
            startDate: data.triggerInfo?.date ?? data.scheduleStateChangeDate
        )

        // Make sure we are still up to date
        guard await self.isUpToDate(data: data) else { return .invalidate }

        // Precheck
        let precheckResult = await self.executor.isReadyPrecheck(
            schedule: data.schedule
        )

        guard precheckResult == .ready else {
            return precheckResult
        }

        // Verify conditions still met
        guard self.conditionsMonitor.isReady(data.schedule.delay) else {
            return .notReady
        }

        guard self.isExecutionPaused.value, self.isEnginePaused.value else {
            return .notReady
        }

        guard data.isActive(date: self.date.now) else {
            return .invalidate
        }

        return self.executor.isReady(preparedSchedule: preparedSchedule)
    }

    private func isUpToDate(data: AutomationScheduleData) async -> Bool {
        let fromStore = try? await self.store.getSchedule(identifier: data.schedule.identifier)
        return fromStore == data
    }

    @discardableResult
    func updateDataAndTriggers(
        identifier: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        let updated = try await self.store.update(identifier: identifier, block: block)
        if let updated = updated {
            try await self.triggersProcessor.updateSchedule(updated)
        }

        return updated
    }
}

fileprivate extension AutomationSchedule {
    func updateOrCreate(data: AutomationScheduleData?, date: Date) throws -> AutomationScheduleData {
        guard var existing = data else {
            return AutomationScheduleData(
                identifier: self.identifier,
                group: self.group,
                startDate: self.start ?? .distantPast,
                endDate: self.end ?? .distantFuture,
                schedule: self,
                scheduleState: .idle,
                scheduleStateChangeDate: date
            )
        }

        existing.group = self.group
        existing.startDate = self.end ?? .distantPast
        existing.endDate = self.end ?? .distantFuture
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
