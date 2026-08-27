/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

actor AutomationEngine : AutomationEngineProtocol {
    internal var startTask: Task<Void, Never>?
    internal var listenerTask: Task<Void, Never>?

    nonisolated internal let isEnginePaused: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)
    nonisolated internal let isExecutionPaused: AirshipMainActorValue<Bool> = AirshipMainActorValue(false)
    private let triggerQueue: AirshipSerialQueue = AirshipSerialQueue()

    private let store: AutomationStore
    private let executor: AutomationExecutor
    private let preparer: AutomationPreparer
    private let scheduleConditionsChangedNotifier: any ScheduleConditionsChangedNotifierProtocol
    private let eventFeed: any AutomationEventFeedProtocol
    private let triggersProcessor: any AutomationTriggerProcessorProtocol
    private let delayProcessor: any AutomationDelayProcessorProtocol
    private let date: any AirshipDateProtocol
    private let taskSleeper: any AirshipTaskSleeper
    private let eventsHistory: any AutomationEventsHistory
    private let ledger: any AutomationLedgerProtocol
    private let limitEvaluator: any LedgerLimitEvaluatorProtocol
    private let groupReservations: LedgerGroupReservations = LedgerGroupReservations()

    private var processPendingExecutionTask: Task<Void, Never>?
    private var needsAnotherPendingExecutionPass: Bool = false
    private var pendingExecution: [String: PreparedData] = [:]
    private var preprocessDelayTasks: Set<Task<Bool, any Error>> = Set()


    init(
        store: AutomationStore,
        executor: AutomationExecutor,
        preparer: AutomationPreparer,
        scheduleConditionsChangedNotifier: any ScheduleConditionsChangedNotifierProtocol,
        eventFeed: any AutomationEventFeedProtocol,
        triggersProcessor: any AutomationTriggerProcessorProtocol,
        delayProcessor: any AutomationDelayProcessorProtocol,
        eventsHistory: any AutomationEventsHistory,
        ledger: any AutomationLedgerProtocol,
        limitEvaluator: any LedgerLimitEvaluatorProtocol,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared
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
        self.eventsHistory = eventsHistory
        self.ledger = ledger
        self.limitEvaluator = limitEvaluator
    }

    @MainActor
    func setEnginePaused(_ paused: Bool) {
        self.isEnginePaused.set(paused)
        self.triggersProcessor.setPaused(paused)

        if !isExecutionPaused.value && !isEnginePaused.value {
            self.scheduleConditionsChangedNotifier.notify()
        }
    }

    @MainActor
    func setExecutionPaused(_ paused: Bool) {
        self.isExecutionPaused.set(paused)

        if !isExecutionPaused.value && !isEnginePaused.value {
            self.scheduleConditionsChangedNotifier.notify()
        }
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
                group.addTask { [weak self = self] in
                    guard
                        !Task.isCancelled,
                        let resultsStream = await self?.triggersProcessor.triggerResults
                    else {
                        return
                    }
                    
                    for await result in resultsStream {
                        guard !Task.isCancelled else { return }
                        await self?.processTriggerResult(result)
                    }
                }

                group.addTask { [weak self = self] in
                    guard
                        !Task.isCancelled,
                        let eventsFeed = self?.eventFeed.feed
                    else {
                        return
                    }
                    
                    for await event in eventsFeed {
                        guard !Task.isCancelled else { return }
                        await self?.triggersProcessor.processEvent(event)
                        await self?.eventsHistory.add(event)
                    }
                }
            }
        }

        Task {
            while true {
                await self.scheduleConditionsChangedNotifier.wait()
                await startProcessingPendingExecution()
            }
        }
    }

    func stop() async {
        self.listenerTask?.cancel()
        self.listenerTask = nil
        
        self.startTask?.cancel()
        self.startTask = nil
    }

    func stopSchedules(identifiers: [String]) async throws {
        AirshipLogger.debug("Stopping schedules \(identifiers)")

        await self.startTask?.value
        let now = self.date.now
        for identifier in identifiers {
            try await self.updateState(identifier: identifier) { data in
                data.schedule.end = now
                data.lastScheduleModifiedDate = now
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

        // The ledger read is async and can't run inside the Core Data block, so
        // resolve each schedule's over-limit state up front and feed it in.
        var resolvedOverLimit: [String: Bool] = [:]
        for (identifier, schedule) in map {
            resolvedOverLimit[identifier] = await self.isOverLimit(schedule: schedule)
        }
        let overLimitByID = resolvedOverLimit

        let updated = try await store.upsertSchedules(scheduleIDs: Array(map.keys)) { [date] identifier, data in
            guard let schedule = map[identifier] else {
                throw AirshipErrors.error("Failed to upsert")
            }

            var updated = try schedule.updateOrCreate(data: data, date: self.date.now)
            updated.updateState(date: date.now, isOverLimit: overLimitByID[identifier] ?? false)
            updated.lastScheduleModifiedDate = date.now
            return updated
        }

        await self.triggersProcessor.updateSchedules(updated)
        self.cancelPreprocessDelayTasks()
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

    func reconcileLedger() async throws {
        await self.startTask?.value
        try await self.store.reconcileLedger(now: self.date.now)
    }
    
    func cancelSchedulesWith(type: AutomationSchedule.ScheduleType) async throws {
        AirshipLogger.debug("Cancelling schedules with type \(type)")

        await self.startTask?.value

        //we don't store schedule type as a separate field, but it's a part of airship json, so we
        // can't utilize core data to filter out our results
        let ids = try await self.schedules.compactMap { schedule in
            switch schedule.data {
            case .actions: return type == .actions ? schedule.identifier : nil
            case .inAppMessage: return type == .inAppMessage ? schedule.identifier : nil
            case .deferred: return type == .deferred ? schedule.identifier : nil
            }
        }

        try await store.deleteSchedules(scheduleIDs: ids)
        await self.triggersProcessor.cancel(scheduleIDs: ids)
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
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)

            if data.scheduleState == .executing, let preparedInfo = data.preparedScheduleInfo {
                let behavior = await self.executor.interrupted(schedule: data.schedule, preparedScheduleInfo: preparedInfo)

                updated = try await self.updateState(data: data) {  data in
                    data.executionInterrupted(date: now, retry: behavior == .retry, isOverLimit: isOverLimit)
                }
                if (updated?.scheduleState == .paused) {
                    handleInterval(updated?.schedule.interval ?? 0.0, scheduleID: data.schedule.identifier)
                }
            } else {
                updated = try await self.updateState(data: data) {  data in
                    data.prepareInterrupted(date: now, isOverLimit: isOverLimit)
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
            do {
                try await self?.taskSleeper.sleep(timeInterval: interval)
                try await self?.updateState(identifier: scheduleID) { data in
                    data.idle(date: date.now)
                }
            } catch {
                AirshipLogger.error("Failed to update schedule state after interval: \(error)")
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
                    let isOverLimit = await self.isOverLimit(scheduleID: result.scheduleID)
                    let updated = try await self.updateState(identifier: result.scheduleID) { data in
                        data.executionCancelled(date: now, isOverLimit: isOverLimit)
                    }

                    if let updated = updated {
                        await self.preparer.cancelled(schedule: updated.schedule)
                    }
                    break

                case .execution:
                    let isOverLimit = await self.isOverLimit(scheduleID: result.scheduleID)
                    let updated = try await self.updateState(identifier: result.scheduleID) { data in
                        data.triggered(triggerInfo: result.triggerInfo, date: now, isOverLimit: isOverLimit)
                    }

                    // Record only when this call actually moved the schedule into
                    // `triggered` for this result. `triggered(...)` is a no-op
                    // unless the schedule was idle, and it stamps this result's
                    // `triggerInfo`, so matching both confirms the transition and
                    // avoids double-counting a redundant trigger result.
                    if let updated,
                       updated.scheduleState == .triggered,
                       updated.triggerInfo == result.triggerInfo {
                        await self.ledger.recordTriggered(
                            scheduleID: updated.schedule.identifier,
                            sharedID: updated.schedule.ledgerSharedID,
                            triggerID: result.triggerInfo.triggerID
                        )
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

        // pause the current context
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

    private func preprocessDelay(data: AutomationScheduleData) async -> Bool {
        guard let delay = data.schedule.delay else { return true }
        let scheduleID = data.schedule.identifier
        let triggerDate = data.triggerInfo?.date ?? data.scheduleStateChangeDate

        let task = Task {
            AirshipLogger.trace("Preprocessing delay \(scheduleID)")
            try await self.delayProcessor.preprocess(
                delay: delay,
                triggerDate: triggerDate
            )
            AirshipLogger.trace("Finished preprocessing delay \(scheduleID)")
            return true
        }

        preprocessDelayTasks.insert(task)
        let result = try? await task.value
        preprocessDelayTasks.remove(task)
        return result ?? false
    }

    private func cancelPreprocessDelayTasks() {
        preprocessDelayTasks.forEach { $0.cancel() }
        preprocessDelayTasks.removeAll()
    }

    private func processTriggeredSchedule(scheduleID: String) async throws {

        if await self.isEnginePaused.value {
            // Wait for resume
            _ = await self.isExecutionPaused.updates.first(where: { paused in paused == false })
        }

        guard
            let data = try await self.store.getSchedule(scheduleID: scheduleID)
        else {
            AirshipLogger.trace("Aborting processing schedule \(scheduleID), no longer in database.")
            return
        }

        guard
            data.isInState([.triggered])
        else {
            AirshipLogger.trace("Aborting processing schedule \(data), no longer triggered.")
            return
        }

        guard 
            await preprocessDelay(data: data)
        else {
            AirshipLogger.trace("Preprocess delay was interrupted, retrying \(scheduleID)")
            try await processTriggeredSchedule(scheduleID: scheduleID)
            return
        }

        guard
            let isCurrent = try? await self.store.isCurrent(
                scheduleID: scheduleID,
                lastScheduleModifiedDate: data.lastScheduleModifiedDate,
                scheduleState: data.scheduleState
            ),
            isCurrent
        else {
            AirshipLogger.trace("Trigger data has changed since preprocessing, retrying \(scheduleID)")
            try await processTriggeredSchedule(scheduleID: scheduleID)
            return
        }

        guard data.isActive(date: self.date.now) else {
            AirshipLogger.trace("Aborting processing schedule \(data), no longer active.")
            await self.preparer.cancelled(schedule: data.schedule)
            return
        }

        /// Prepare
        guard let prepared = try await self.prepareSchedule(data: data) else {
            return
        }

        try await processPrepared(preparedData: prepared)
    }


    private func processPrepared(preparedData: PreparedData) async throws {
        await waitForConditions(preparedData: preparedData)

        guard await checkStillValid(prepared: preparedData) else {
            let isOverLimit = await self.isOverLimit(schedule: preparedData.scheduleData.schedule)
            let updated = try await self.updateState(data: preparedData.scheduleData) { [date] data in
                data.executionInvalidated(date: date.now, isOverLimit: isOverLimit)
            }

            if updated?.scheduleState == .triggered {
                await self.startTaskToProcessTriggeredSchedule(
                    scheduleID: preparedData.scheduleID
                )
            } else {
                await self.preparer.cancelled(schedule: preparedData.scheduleData.schedule)
            }
            return
        }

        self.addPending(preparedData: preparedData)
        await self.startProcessingPendingExecution()
    }

    private func startProcessingPendingExecution() async {
        // Drains must not overlap: two of them pulling from `pendingExecution` can
        // select the same schedule, because there are awaits between picking it and
        // removing it. Queueing one per caller is wasteful though — a drain re-reads
        // `pendingExecution` from scratch, so only one waiting behind the running
        // one is ever useful.
        guard self.processPendingExecutionTask != nil else {
            self.processPendingExecutionTask = Task { await self.processPendingExecution() }
            return
        }

        guard self.needsAnotherPendingExecutionPass == false else { return }
        self.needsAnotherPendingExecutionPass = true

        let previous = self.processPendingExecutionTask
        self.processPendingExecutionTask = Task {
            await previous?.value
            self.needsAnotherPendingExecutionPass = false
            await self.processPendingExecution()
        }
    }

    private func processPendingExecution() async {
        var processedScheduleIDs = Set<String>()

        while true {
            let next = self.pendingExecution.values.filter { data in
                !processedScheduleIDs.contains(data.scheduleID)
            }.sorted { l, r in
                l.priority < r.priority
            }.first

            guard let next else { return }

            processedScheduleIDs.insert(next.scheduleID)

            guard
                await checkStillValid(prepared: next),
                await self.delayProcessor.areConditionsMet(delay: next.scheduleData.schedule.delay)
            else {
                self.pendingExecution.removeValue(forKey: next.scheduleID)
                Task {
                    do {
                        try await processPrepared(preparedData: next)
                    } catch {
                        AirshipLogger.error("Failed to execute schedule \(next.scheduleData) \(error)")
                    }
                }
                continue
            }

            self.pendingExecution.removeValue(forKey: next.scheduleID)

            Task { @MainActor in
                do {
                    let handled = try await attemptExecution(
                        data: next.scheduleData,
                        preparedSchedule: next.preparedSchedule
                    )

                    if (!handled) {
                        await addPending(preparedData: next)
                    }
                } catch {
                    AirshipLogger.error("Failed to execute schedule \(next.scheduleData) \(error)")
                }
            }
        }
    }

    private func addPending(preparedData: PreparedData) {
        AirshipLogger.trace("Adding \(preparedData.scheduleID) to pending execution queue")
        self.pendingExecution[preparedData.scheduleID] = preparedData
    }


    private func checkStillValid(prepared: PreparedData) async -> Bool {
        // Make sure we are still up to date. Data might change due to a change
        // in the data, schedule was cancelled, or if a delay cancellation trigger
        // was fired.
        guard
            let isCurrent = try? await self.store.isCurrent(
                scheduleID: prepared.scheduleID,
                lastScheduleModifiedDate: prepared.scheduleData.lastScheduleModifiedDate,
                scheduleState: prepared.scheduleData.scheduleState
            ),
            isCurrent
        else {
            AirshipLogger.trace("Prepared schedule no longer up to date, no longer valid \(prepared.scheduleData)")
            return false
        }

        guard prepared.scheduleData.isActive(date: self.date.now) else {
            AirshipLogger.trace("Prepared schedule no longer active, no longer valid \(prepared.scheduleData)")
            return false
        }

        guard await self.executor.isValid(
            schedule: prepared.scheduleData.schedule
        ) else {
            AirshipLogger.trace("Prepared schedule no longer valid \(prepared.scheduleData)")
            return false
        }

        return true
    }

    private func waitForConditions(preparedData: PreparedData) async  {
        let triggerDate = preparedData.scheduleData.triggerInfo?.date ?? preparedData.scheduleData.scheduleStateChangeDate

        // Wait for conditions
        AirshipLogger.trace("Waiting for delay conditions \(preparedData.scheduleID)")
        await self.delayProcessor.process(
            delay: preparedData.scheduleData.schedule.delay,
            triggerDate: triggerDate
        )

        AirshipLogger.trace("Delay conditions met \(preparedData.scheduleID)")
    }


    private func prepareSchedule(data: AutomationScheduleData) async throws -> PreparedData? {
        AirshipLogger.trace("Preparing schedule \(data.schedule.identifier)")

        let prepareResult = await self.preparer.prepare(
            schedule: data.schedule,
            triggerContext: data.triggerInfo?.context,
            triggerSessionID: data.triggerSessionID,
            triggerID: data.triggerInfo?.triggerID
        )

        AirshipLogger.trace("Finished preparing schedule \(data.schedule.identifier) result: \(prepareResult)")

        switch prepareResult {
        case .prepared(let preparedSchedule):
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            let updated = try await self.updateState(data: data) { [date] data in
                data.prepared(info: preparedSchedule.info, date: date.now, isOverLimit: isOverLimit)
            }

            // Make sure the transition actually applied. The schedule might have left
            // the `triggered` state while prepare was in flight (e.g., a delay
            // cancellation trigger fired), making `prepared` a no-op.
            guard
                let updated,
                updated.scheduleState == .prepared,
                updated.preparedScheduleInfo == preparedSchedule.info
            else {
                await preparer.cancelled(schedule: data.schedule)
                return nil
            }

            return PreparedData(
                scheduleData: updated,
                preparedSchedule: preparedSchedule
            )
        case .invalidate:
            await self.startTaskToProcessTriggeredSchedule(
                scheduleID: data.schedule.identifier
            )
            return nil
        case .cancel:
            try await self.store.deleteSchedules(scheduleIDs: [data.schedule.identifier])
            return nil
        case .skip:
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            _ = try await self.updateState(data: data) { [date] data in
                data.prepareCancelled(date: date.now, penalize: false, isOverLimit: isOverLimit)
            }
            return nil
        case .penalize:
            // The audience-miss ledger event was recorded during prepare, so the
            // ledger read here reflects it when deciding whether to finish.
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            _ = try await self.updateState(data: data) { [date] data in
                data.prepareCancelled(date: date.now, penalize: true, isOverLimit: isOverLimit)
            }
            return nil
        }
    }

    /// Applies the state changes a non-ready ``checkReady`` result calls for.
    ///
    /// - Returns: what `attemptExecution` should return, or nil when the schedule
    /// is ready and execution should continue.
    @MainActor
    private func applyNonReadyActions(
        _ result: ScheduleReadyResult,
        data: AutomationScheduleData
    ) async throws -> Bool? {
        switch (result) {
        case .ready:
            return nil

        case .invalidate:
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            let updated = try await self.updateState(data: data) { [date] data in
                data.executionInvalidated(date: date.now, isOverLimit: isOverLimit)
            }

            if updated?.scheduleState == .triggered {
                await self.startTaskToProcessTriggeredSchedule(
                    scheduleID: data.schedule.identifier
                )
            } else {
                await self.preparer.cancelled(schedule: data.schedule)
            }
            return true

        case .notReady:
            return false

        case .skip:
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            try await self.updateState(data: data) { [date] data in
                data.executionSkipped(date: date.now, isOverLimit: isOverLimit)
            }
            await self.preparer.cancelled(schedule: data.schedule)
            return true
        }
    }

    @MainActor
    private func attemptExecution(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) async throws -> Bool {
        AirshipLogger.trace("Starting to execute schedule \(data)")


        if let handled = try await self.applyNonReadyActions(
            self.checkReady(data: data, preparedSchedule: preparedSchedule),
            data: data
        ) {
            return handled
        }


        // Schedules sharing a `ledger_config.shared_id` share one execution budget,
        // so another schedule using that ID may have spent it since this one was
        // prepared. Without a shared ID nothing else can add to the count, since
        // the only thing that does is executing, which cannot happen while waiting.
        //
        // This runs even for schedules that skip the reservation below, since the
        // budget can be spent either way.
        if data.schedule.ledgerSharedID != nil,
           await self.isOverLimit(schedule: data.schedule) {
            AirshipLogger.trace(
                "Over ledger limit at execution time, skipping \(data.schedule.identifier)"
            )
            try await self.updateState(data: data) { [date] data in
                data.executionSkipped(date: date.now, isOverLimit: true)
            }
            await self.preparer.cancelled(schedule: data.schedule)
            return true
        }

        let reservedGroupID: String? = preparedSchedule.reservesLedgerGroup
            ? data.schedule.ledgerSharedID
            : nil
        if let reservedGroupID {

            // Hold the group for the duration of the execution. The check above
            // cannot see a sibling that is mid-display, because its event is not
            // written until the display ends — the reservation covers exactly
            // that window. Suspending here holds nothing else up: the drain
            // dispatches executions without awaiting them, so only this group
            // queues behind the holder.
            await self.groupReservations.reserve(reservedGroupID)

            // Waking can be much later — a sibling's display may have run for
            // minutes. Everything `checkReady` established above may be stale by
            // now: execution could have been paused, or the schedule could have
            // expired. Re-validate instead of walking straight into `execute`,
            // and requeue so the normal path re-evaluates from the top.
            // Release before handling, so the outcome's own cleanup — which can
            // re-enter the engine — never runs while holding the group.
            let readyAfterWaiting = self.checkReady(data: data, preparedSchedule: preparedSchedule)
            if readyAfterWaiting != .ready {
                AirshipLogger.trace(
                    "No longer ready after waiting on ledger group \(reservedGroupID): \(data.schedule.identifier)"
                )
                await self.releaseGroup(reservedGroupID)

                // Released first: `applyNonReadyActions` always returns or throws for a
                // non-`.ready` result, so a trailing release would be skipped and
                // the group wedged. `?? false` keeps that guarantee structural
                // rather than relying on the mapping staying non-nil.
                return try await self.applyNonReadyActions(readyAfterWaiting, data: data) ?? false
            }

            // `checkReady` covers pause, expiry and display readiness, but not
            // whether the definition still exists: that lives in `checkStillValid`,
            // which the drain runs microseconds before dispatching. Waiting on the
            // group makes that gap unbounded, long enough for a remote-data refresh
            // to remove or replace the campaign while a sibling was displaying.
            guard await self.checkStillValid(
                prepared: PreparedData(scheduleData: data, preparedSchedule: preparedSchedule)
            ) else {
                AirshipLogger.trace(
                    "No longer valid after waiting on ledger group \(reservedGroupID): \(data.schedule.identifier)"
                )
                await self.releaseGroup(reservedGroupID)
                return try await self.applyNonReadyActions(.invalidate, data: data) ?? false
            }

            // The previous holder has recorded by now, so the ledger can answer.
            if await self.isOverLimit(schedule: data.schedule) {
                AirshipLogger.trace(
                    "Ledger group \(reservedGroupID) spent while waiting, skipping \(data.schedule.identifier)"
                )
                await self.releaseGroup(reservedGroupID)
                try await self.updateState(data: data) { [date] data in
                    data.executionSkipped(date: date.now, isOverLimit: true)
                }
                await self.preparer.cancelled(schedule: data.schedule)
                return true
            }
        }

        // Charged here rather than as part of `checkReady`, and so exactly once:
        // recording an occurrence is a spend, and readiness is evaluated twice on
        // the reserved path. Doing it last also keeps the occurrence off attempts
        // that were ready but got skipped above by the ledger.
        guard self.executor.checkFrequencyLimit(preparedSchedule: preparedSchedule) else {
            AirshipLogger.trace(
                "Over frequency limit, skipping \(data.schedule.identifier)"
            )
            await self.releaseGroup(reservedGroupID)
            return try await self.applyNonReadyActions(.skip, data: data) ?? false
        }

        let executeResult: ScheduleExecuteResult
        do {
            executeResult = try await self.execute(preparedSchedule: preparedSchedule)
        } catch {
            await self.releaseGroup(reservedGroupID)
            throw error
        }
        await self.releaseGroup(reservedGroupID)

        let scheduleID = data.schedule.identifier

        switch (executeResult) {
        case .cancel:
            try await self.store.deleteSchedules(scheduleIDs: [scheduleID])
            await self.triggersProcessor.cancel(scheduleIDs: [scheduleID])
            return true

        case .finished:
            // The execution ledger event was recorded during `execute`, so the
            // ledger read here counts it when deciding whether the limit is hit.
            let isOverLimit = await self.isOverLimit(schedule: data.schedule)
            let updated = try await self.updateState(identifier: scheduleID) {  [date] data in
                data.finishedExecuting(date: date.now, isOverLimit: isOverLimit)
            }

            if let updated = updated, updated.scheduleState == .paused {
                await handleInterval(updated.schedule.interval ?? 0.0, scheduleID: updated.schedule.identifier)
            }
            return true

        case .retry:
            return false
        }
    }

    @MainActor
    private func execute(preparedSchedule: PreparedSchedule) async throws -> ScheduleExecuteResult {
        AirshipLogger.trace("Executing schedule \(preparedSchedule.info.scheduleID)")

        // Execute
        let updateStateTask = Task {
            try await self.updateState(identifier: preparedSchedule.info.scheduleID) { [date] data in
                data.executing(date: date.now)
            }
        }

        let executeResult = await self.executor.execute(
            preparedSchedule: preparedSchedule
        )

        _ = try await updateStateTask.value

        AirshipLogger.trace("Executing result \(preparedSchedule.info.scheduleID) \(executeResult)")

        return executeResult
    }

    /// Releases a group reservation, letting the next execution in that group run.
    private func releaseGroup(_ sharedID: String?) async {
        guard let sharedID else { return }
        await self.groupReservations.release(sharedID)
    }

    @MainActor
    private func checkReady(data: AutomationScheduleData, preparedSchedule: PreparedSchedule) -> ScheduleReadyResult {
        AirshipLogger.trace("Checking if schedule is ready \(data)")

        // Execution should not be paused
        guard !self.isExecutionPaused.value, !self.isEnginePaused.value else {
            AirshipLogger.trace("Executor paused, not ready \(data)")
            return .notReady
        }

        // Still active
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

    /// Same as updateState(identifier:block) but optimized to skip parsing the schedule if last modified time
    /// is unchanged. This reduces energy usage by avoiding unnecessary schedule parsing.
    /// TODO: Move start/end to top level of schedule to allow state-only mutations without full parsing.
    @discardableResult
    func updateState(
        data: AutomationScheduleData,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        let updated = try await self.store.updateSchedule(scheduleData: data, block:block)
        if let updated  {
            try await self.triggersProcessor.updateScheduleState(
                scheduleID: updated.schedule.identifier,
                state: updated.scheduleState
            )
        }
        return updated
    }

    @discardableResult
    func updateState(
        identifier: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void
    ) async throws -> AutomationScheduleData? {
        let updated = try await self.store.updateSchedule(scheduleID: identifier, block: block)
        if let updated  {
            try await self.triggersProcessor.updateScheduleState(
                scheduleID: identifier,
                state: updated.scheduleState
            )
        }
        return updated
    }

    /// Whether the schedule has reached its limit according to the ledger.
    /// Used to feed the authoritative over-limit value into state transitions.
    func isOverLimit(schedule: AutomationSchedule) async -> Bool {
        return await self.limitEvaluator.isOverLimit(schedule: schedule)
    }

    /// Convenience that looks up the schedule by ID before evaluating its
    /// ledger limit. Returns `false` when the schedule can't be loaded, erring
    /// toward continuing rather than silently finishing.
    func isOverLimit(scheduleID: String) async -> Bool {
        guard let data = try? await self.store.getSchedule(scheduleID: scheduleID) else {
            return false
        }
        return await self.isOverLimit(schedule: data.schedule)
    }
}

fileprivate extension AutomationSchedule {
    func updateOrCreate(data: AutomationScheduleData?, date: Date) throws -> AutomationScheduleData {
        guard var existing = data else {
            return AutomationScheduleData(
                schedule: self,
                scheduleState: .idle,
                lastScheduleModifiedDate: date,
                scheduleStateChangeDate: date,
                executionCount: 0,
                triggerSessionID: UUID().uuidString
            )
        }

        existing.schedule = self
        return existing
    }
}

fileprivate struct PreparedData: Sendable {
    fileprivate let scheduleData: AutomationScheduleData
    fileprivate let preparedSchedule: PreparedSchedule

    fileprivate var scheduleID: String {
        return scheduleData.schedule.identifier
    }

    fileprivate var priority: Int {
        return scheduleData.schedule.priority ?? 0
    }
}

/// Automation engine
protocol AutomationEngineProtocol: Actor, Sendable {
    @MainActor
    func setEnginePaused(_ paused: Bool)

    @MainActor
    func setExecutionPaused(_ paused: Bool)
    func start() async

    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws

    func stopSchedules(identifiers: [String]) async throws
    func cancelSchedules(identifiers: [String]) async throws
    func cancelSchedules(group: String) async throws
    func cancelSchedulesWith(type: AutomationSchedule.ScheduleType) async throws

    /// Reconciles the ledger against current schedules: retention + compaction.
    func reconcileLedger() async throws

    var schedules: [AutomationSchedule] { get async throws }
    func getSchedule(identifier: String) async throws -> AutomationSchedule?
    func getSchedules(group: String) async throws -> [AutomationSchedule]
}

fileprivate extension PreparedSchedule {
    /// Whether this schedule should hold its ledger group while it executes.
    ///
    /// Embedded messages are excluded. Their display resolves only when the view
    /// is unmounted, which can be the rest of the session — or never, if no
    /// ``AirshipEmbeddedView`` is ever mounted for the ID — so holding the group
    /// across one would park every sibling indefinitely. They are also built to
    /// run alongside others: ``EmbeddedDisplayCoordinator`` does not count them as
    /// displaying for any other coordinator, so serializing them would contradict
    /// that. (``ImmediateDisplayCoordinator`` messages share that intent, but
    /// their displays resolve, so queueing one behind a sibling is bounded.)
    ///
    /// The trade-off is that a pooled group of embedded messages can still
    /// over-display; the ledger limit remains their only bound.
    var reservesLedgerGroup: Bool {
        switch self.data {
        case .inAppMessage(let messageData): return !messageData.message.isEmbedded
        case .actions: return true
        }
    }
}
