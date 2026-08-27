/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
final class TestScheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifierProtocol {
    var onNotify: (() -> Void)?
    var onWait: (() -> Void)?

    func notify() {
        onNotify?()
    }
    
    func wait() async {
        onWait?()
    }
}

@MainActor
final class AutomationEngineTest {
    
    private var engine: AutomationEngine!
    private var dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var automationStore: AutomationStore!
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let actionPreparer: TestPreparerDelegate<AirshipJSON, AirshipJSON> = TestPreparerDelegate()
    private let messagePreparer: TestPreparerDelegate<InAppMessage, PreparedInAppMessageData> = TestPreparerDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private var privacyManager: TestPrivacyManager!
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()
    private let experiments: TestExperimentDataProvider = TestExperimentDataProvider()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()
    private let ledger: TestAutomationLedger = TestAutomationLedger()
    private let triggersProcessor: TestAutomationTriggerProcessor = TestAutomationTriggerProcessor()
    private var preparer: AutomationPreparer!
    private var eventFeed: AutomationEventFeed!
    private var executor: AutomationExecutor!
    private var messageExecutor: InAppMessageAutomationExecutor!
    private var delayProcessor: AutomationDelayProcessor!
    private var metrics: ApplicationMetrics!
    private let runtimeConfig: RuntimeConfig = .testConfig()

    private var scheduleConditionsChangedNotifier: TestScheduleConditionsChangedNotifier!
    init() async throws {
        let history = DefaultAutomationEventsHistory(clock: UATestDate())
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: runtimeConfig,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        let automationStoreAppKey = UUID().uuidString
        let ledgerStore = LedgerStore(appKey: automationStoreAppKey, inMemory: true)
        self.automationStore = AutomationStore(
            appKey: automationStoreAppKey,
            inMemory: true,
            ledgerStore: ledgerStore
        )
        let limitEvaluator = LedgerLimitEvaluator(store: ledgerStore)
        self.preparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: audienceChecker,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess,
            config: self.runtimeConfig,
            additionalAudienceResolver: TestAdditionalAudienceResolver(),
            ledger: NoOpAutomationLedger()
        )

        // The trigger-driven ledger tests below let the engine reach the
        // preparer's `cancelled` path; give it an inert block so it doesn't
        // force-unwrap a nil handler.
        self.actionPreparer.cancelledBlock = { _ in }
        self.messagePreparer.cancelledBlock = { _ in }

        let actionExecutor = ActionAutomationExecutor(ledger: NoOpAutomationLedger())
        let messageExecutor = TestInAppMessageAutomationExecutor()
        let executor = AutomationExecutor(actionExecutor: actionExecutor, messageExecutor: messageExecutor, remoteDataAccess: remoteDataAccess)
        
        self.metrics = ApplicationMetrics(
            dataStore: dataStore,
            privacyManager: privacyManager,
            notificationCenter: self.notificationCenter,
            appVersion: "1.0.0"
        )

        let analyticsFeed = AirshipAnalyticsFeed() { true }
        self.scheduleConditionsChangedNotifier = TestScheduleConditionsChangedNotifier()
        eventFeed = AutomationEventFeed(applicationMetrics: metrics, applicationStateTracker: AppStateTracker.shared, analyticsFeed: analyticsFeed)
        let analytics = TestAnalytics()
        let delayProcessor = AutomationDelayProcessor(analytics: analytics)
        
        self.engine = AutomationEngine(
            store: self.automationStore,
            executor: executor,
            preparer: self.preparer,
            scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier,
            eventFeed: eventFeed,
            triggersProcessor: self.triggersProcessor,
            delayProcessor: delayProcessor,
            eventsHistory: history,
            ledger: self.ledger,
            limitEvaluator: limitEvaluator
        )
    }
    
    deinit {
        let engine = self.engine
        Task {
            await engine?.stop()
        }
    }
    
    @Test
    func testStart() async throws {
        await self.engine.start()
        let startTask = await self.engine.startTask
        let listenTask = await self.engine.listenerTask
        
        #expect(startTask != nil)
        #expect(listenTask != nil)
    }
    
    @Test
    func testStop() async throws {
        await self.engine.stop()
        let startTask = await self.engine.startTask
        let listenTask = await self.engine.listenerTask
        #expect(startTask == nil)
        #expect(listenTask == nil)
    }
    
    @Test
    func testSetEnginePaused() async throws {
        self.engine.setEnginePaused(true)
        #expect(self.engine.isEnginePaused.value)
    }
    
    @Test
    func testSetExecutionPaused() async throws {
        await confirmation("Schedule conditions changed notifiers should be notified when pause state changes.") { confirm in
            self.scheduleConditionsChangedNotifier.onNotify = {
                confirm()
            }

            self.engine.setExecutionPaused(true)
            #expect(self.engine.isExecutionPaused.value)


            self.engine.setExecutionPaused(false)
            #expect(!(self.engine.isExecutionPaused.value))
        }
    }
    
    @Test
    func testStopSchedules() async throws {
        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        var schedule = try await self.engine.getSchedule(identifier: "test")
        #expect(schedule != nil)
        try await self.engine.stopSchedules(identifiers: ["test"])
        schedule = try await self.engine.getSchedule(identifier: "test")
        #expect(schedule == nil)
    }
    
    @Test
    func testUpsertSchedules() async throws {
        var schedule = try await self.engine.getSchedule(identifier: "test")
        #expect(schedule == nil)

        var storedSchedule = try await self.automationStore.getSchedule(scheduleID: "test")
        #expect(storedSchedule == nil)

        let beforeDate = AirshipDate().now

        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        schedule = try await self.engine.getSchedule(identifier: "test")

        storedSchedule = try await self.automationStore.getSchedule(scheduleID: "test")

        #expect(storedSchedule!.lastScheduleModifiedDate > beforeDate)
        #expect(schedule != nil)
    }
    
    @Test
    func testCancelSchedule() async throws {
        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        try await self.engine.cancelSchedules(identifiers: ["test"])
        let schedule = try await self.engine.getSchedule(identifier: "test")
        #expect(schedule == nil)
    }

    /// An execution-type trigger result that moves an idle schedule into
    /// `triggered` must record a `triggered` ledger event, stamped with the
    /// schedule's shared ID and the causing trigger's ID.
    @Test
    func testExecutionTriggerRecordsTriggered() async throws {
        try await self.engine.upsertSchedules([
            makeSchedule(id: "record-schedule", sharedID: "group-1")
        ])

        // Pause so the schedule records `triggered` but halts before the
        // preparer/executor pipeline, keeping the test focused on recording.
        self.engine.setEnginePaused(true)
        self.engine.setExecutionPaused(true)
        await self.engine.start()

        await self.triggersProcessor.emit(
            TriggerResult(
                scheduleID: "record-schedule",
                triggerExecutionType: .execution,
                triggerInfo: TriggeringInfo(date: Date(), triggerID: "trigger-1")
            )
        )

        try await waitForTriggeredRecord(scheduleID: "record-schedule")

        let recorded = await self.ledger.recorded
        #expect(recorded == [
            .triggered(scheduleID: "record-schedule", sharedID: "group-1", triggerID: "trigger-1")
        ])
    }

    /// A delay-cancellation trigger result must not record a `triggered`
    /// event. A second execution result gives a deterministic barrier: because
    /// results are processed serially, once the barrier's record appears the
    /// cancellation has already been processed, so its absence is conclusive.
    @Test
    func testDelayCancellationDoesNotRecordTriggered() async throws {
        try await self.engine.upsertSchedules([
            makeSchedule(id: "cancel-schedule"),
            makeSchedule(id: "barrier-schedule", sharedID: "barrier-group")
        ])

        self.engine.setEnginePaused(true)
        self.engine.setExecutionPaused(true)
        await self.engine.start()

        await self.triggersProcessor.emit(
            TriggerResult(
                scheduleID: "cancel-schedule",
                triggerExecutionType: .delayCancellation,
                triggerInfo: TriggeringInfo(date: Date(), triggerID: "trigger-cancel")
            )
        )

        await self.triggersProcessor.emit(
            TriggerResult(
                scheduleID: "barrier-schedule",
                triggerExecutionType: .execution,
                triggerInfo: TriggeringInfo(date: Date(), triggerID: "trigger-barrier")
            )
        )

        try await waitForTriggeredRecord(scheduleID: "barrier-schedule")

        let recorded = await self.ledger.recorded
        #expect(recorded == [
            .triggered(scheduleID: "barrier-schedule", sharedID: "barrier-group", triggerID: "trigger-barrier")
        ])
    }

    private func makeSchedule(id: String, sharedID: String? = nil) -> AutomationSchedule {
        AutomationSchedule(
            identifier: id,
            data: .inAppMessage(
                InAppMessage(name: "test", displayContent: .custom(.string("test")))
            ),
            triggers: [],
            ledgerConfig: sharedID.map { .init(sharedID: $0) }
        )
    }

    private func waitForTriggeredRecord(
        scheduleID: String,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let recorded = await self.ledger.recorded
            let found = recorded.contains {
                if case .triggered(let sid, _, _) = $0 { return sid == scheduleID }
                return false
            }
            if found { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        Issue.record("Timed out waiting for triggered record for \(scheduleID)")
    }
}

/// Trigger processor double that lets a test push `TriggerResult`s straight
/// into the engine's results stream, so trigger-driven engine behavior can be
/// exercised deterministically without real event ingestion timing.
final actor TestAutomationTriggerProcessor: AutomationTriggerProcessorProtocol {
    private let stream: AsyncStream<TriggerResult>
    private let continuation: AsyncStream<TriggerResult>.Continuation

    init() {
        (self.stream, self.continuation) = AsyncStream<TriggerResult>.airshipMakeStreamWithContinuation()
    }

    func emit(_ result: TriggerResult) {
        self.continuation.yield(result)
    }

    @MainActor
    func setPaused(_ paused: Bool) {}

    var triggerResults: AsyncStream<TriggerResult> {
        return self.stream
    }

    func processEvent(_ event: AutomationEvent) async {}
    func restoreSchedules(_ datas: [AutomationScheduleData]) async throws {}
    func updateSchedules(_ datas: [AutomationScheduleData]) async {}
    func updateScheduleState(scheduleID: String, state: AutomationScheduleState) async throws {}
    func cancel(scheduleIDs: [String]) async {}
    func cancel(group: String) async {}
}

actor TestAdditionalAudienceResolver: AdditionalAudienceCheckerResolverProtocol {
    struct ResolveRequest {
        let channelID: String
        let contactID: String?
        let overrides: AdditionalAudienceCheckOverrides?
    }
    
    var recordedReqeusts: [ResolveRequest] = []
    public func setResult(_ result: Bool) {
        returnResult = result
    }
    private var returnResult = true

    func resolve(
        deviceInfoProvider: AudienceDeviceInfoProvider,
        additionalAudienceCheckOverrides: AdditionalAudienceCheckOverrides?
    ) async throws -> Bool {
        recordedReqeusts.append(
            ResolveRequest(
                channelID: try await deviceInfoProvider.channelID,
                contactID: await deviceInfoProvider.stableContactInfo.contactID,
                overrides: additionalAudienceCheckOverrides
            )
        )
        return returnResult
    }
}

/// Action runner that counts runs and can hold one open, standing in for a
/// message that stays on screen until dismissed.
final class TestHoldableActionRunner: AutomationActionRunnerProtocol, @unchecked Sendable {
    private let _runs = AirshipAtomicValue(0)
    var runs: Int { _runs.value }

    /// Invoked with the 1-based run index while the action is still running.
    var onRunning: (@Sendable (Int) async -> Void)?

    func runActions(_ actions: AirshipJSON, situation: ActionSituation, metadata: [String: any Sendable]) async {
        let index = _runs.getAndUpdate { $0 += 1 }
        await onRunning?(index)
    }
}

/// Schedules sharing a `ledger_config.shared_id` pool one execution budget, so
/// the limit has to hold across schedules and not just within one. The ledger is
/// read outside the store transaction that moves the schedule's state, which
/// makes every limit decision a check-then-act; these cover the two orderings
/// that used to slip through it.
@MainActor
final class SharedLedgerGroupLimitTest {

    private let deviceInfoProvider = TestDeviceInfoProvider()
    private let runtimeConfig: RuntimeConfig = .testConfig()
    private let runner = TestHoldableActionRunner()
    private let triggersProcessor = TestAutomationTriggerProcessor()
    private let frequencyLimits = TestFrequencyLimitManager()
    private var engine: AutomationEngine!

    /// Schedules remote data has dropped. Mutable mid-test, so a schedule can go
    /// stale while it is parked on a group.
    private let staleScheduleIDs = AirshipAtomicValue<Set<String>>([])

    /// Validity checks per schedule, which is how a test tells that the check
    /// after the wait actually ran and not just the ones before dispatch.
    private let isCurrentCalls = AirshipAtomicValue<[String: Int]>([:])

    init() async throws {
        let appKey = UUID().uuidString
        let ledgerStore = LedgerStore(appKey: appKey, inMemory: true)
        let automationStore = AutomationStore(
            appKey: appKey, inMemory: true, ledgerStore: ledgerStore
        )

        // A real recorder, so executions actually land in the ledger and the
        // limit evaluator can see them.
        let ledger = AutomationLedger(store: ledgerStore)

        let actionPreparer = TestPreparerDelegate<AirshipJSON, AirshipJSON>()
        actionPreparer.prepareBlock = { data, _ in data }
        actionPreparer.cancelledBlock = { _ in }

        let messagePreparer = TestPreparerDelegate<InAppMessage, PreparedInAppMessageData>()
        messagePreparer.cancelledBlock = { _ in }

        let remoteDataAccess = TestRemoteDataAccess()
        remoteDataAccess.bestEffortRefreshBlock = { _ in true }
        remoteDataAccess.contactIDBlock = { _ in "contact" }
        remoteDataAccess.isCurrentBlock = { [staleScheduleIDs = self.staleScheduleIDs, isCurrentCalls = self.isCurrentCalls] schedule in
            isCurrentCalls.update { $0[schedule.identifier, default: 0] += 1 }
            return !staleScheduleIDs.value.contains(schedule.identifier)
        }
        // A dropped schedule stays dropped, so re-preparing it parks on the
        // refresh rather than spinning through invalidate → prepare → invalidate
        // for the rest of the test.
        remoteDataAccess.requiresUpdateBlock = { [staleScheduleIDs = self.staleScheduleIDs] schedule in
            staleScheduleIDs.value.contains(schedule.identifier)
        }
        remoteDataAccess.waitFullRefreshBlock = { _ in
            _ = try? await Task.sleep(nanoseconds: 5_000_000_000)
        }

        let preparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: TestDeferredResolver(),
            frequencyLimits: self.frequencyLimits,
            audienceChecker: TestAudienceChecker(),
            experiments: TestExperimentDataProvider(),
            remoteDataAccess: remoteDataAccess,
            config: self.runtimeConfig,
            deviceInfoProviderFactory: { [provider = self.deviceInfoProvider] contactID in
                provider.stableContactInfo = StableContactInfo(contactID: contactID ?? UUID().uuidString)
                return provider
            },
            additionalAudienceResolver: TestAdditionalAudienceResolver(),
            ledger: ledger
        )

        let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        let notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
        let privacyManager = TestPrivacyManager(
            dataStore: dataStore, config: runtimeConfig,
            defaultEnabledFeatures: .all, notificationCenter: notificationCenter
        )

        self.engine = AutomationEngine(
            store: automationStore,
            executor: AutomationExecutor(
                actionExecutor: ActionAutomationExecutor(
                    actionRunner: self.runner, ledger: ledger
                ),
                messageExecutor: TestInAppMessageAutomationExecutor(),
                remoteDataAccess: remoteDataAccess
            ),
            preparer: preparer,
            scheduleConditionsChangedNotifier: TestScheduleConditionsChangedNotifier(),
            eventFeed: AutomationEventFeed(
                applicationMetrics: ApplicationMetrics(
                    dataStore: dataStore, privacyManager: privacyManager,
                    notificationCenter: notificationCenter, appVersion: "1.0.0"
                ),
                applicationStateTracker: AppStateTracker.shared,
                analyticsFeed: AirshipAnalyticsFeed { true }
            ),
            triggersProcessor: self.triggersProcessor,
            delayProcessor: AutomationDelayProcessor(analytics: TestAnalytics()),
            eventsHistory: DefaultAutomationEventsHistory(clock: UATestDate()),
            ledger: ledger,
            limitEvaluator: LedgerLimitEvaluator(store: ledgerStore)
        )
    }

    deinit {
        let engine = self.engine
        Task { await engine?.stop() }
    }

    private func schedule(
        _ identifier: String,
        sharedID: String,
        limit: UInt = 1,
        frequencyConstraintIDs: [String]? = nil
    ) -> AutomationSchedule {
        AutomationSchedule(
            identifier: identifier,
            data: .actions(.string("run-\(identifier)")),
            triggers: [],
            limit: limit,
            ledgerConfig: .init(sharedID: sharedID),
            frequencyConstraintIDs: frequencyConstraintIDs
        )
    }

    private func emitExecutionTrigger(_ scheduleID: String, triggerID: String) async {
        await self.triggersProcessor.emit(
            TriggerResult(
                scheduleID: scheduleID,
                triggerExecutionType: .execution,
                triggerInfo: TriggeringInfo(date: Date(), triggerID: triggerID)
            )
        )
    }

    /// Both members of a `limit: 1` group triggered together must execute once
    /// between them, not once each.
    @Test
    func testGroupLimitHoldsAcrossSchedulesTriggeredTogether() async throws {
        try await self.engine.upsertSchedules([
            schedule("group-a", sharedID: "group"),
            schedule("group-b", sharedID: "group")
        ])

        await self.engine.start()
        await emitExecutionTrigger("group-a", triggerID: "trigger-a")
        await emitExecutionTrigger("group-b", triggerID: "trigger-b")

        for _ in 0..<150 {
            if self.runner.runs >= 1 { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        // Give a second execution room to land if the limit did not hold.
        try? await Task.sleep(nanoseconds: 300_000_000)

        #expect(self.runner.runs == 1)
    }

    /// The sibling is triggered while the first execution is still in flight, so
    /// the ledger has not been written yet and re-reading it cannot help. The
    /// group reservation covers that window.
    @Test
    func testGroupLimitHoldsWhileFirstExecutionIsInFlight() async throws {
        try await self.engine.upsertSchedules([
            schedule("held-a", sharedID: "held-group"),
            schedule("held-b", sharedID: "held-group")
        ])

        let firstIsRunning = AirshipAtomicValue(false)
        let releaseFirst = AirshipAtomicValue(false)
        self.runner.onRunning = { index in
            guard index == 1 else { return }
            firstIsRunning.set(true)
            for _ in 0..<150 {
                if releaseFirst.value { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        await self.engine.start()
        await emitExecutionTrigger("held-a", triggerID: "trigger-a")

        for _ in 0..<150 {
            if firstIsRunning.value { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(firstIsRunning.value)

        await emitExecutionTrigger("held-b", triggerID: "trigger-b")
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if self.runner.runs >= 2 { break }
        }

        releaseFirst.set(true)
        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(self.runner.runs == 1)
    }

    /// A pooled schedule has its readiness evaluated twice — before and after
    /// waiting on the group — so the frequency budget cannot be charged as part
    /// of that check. With a 1-per-window constraint, charging it twice made the
    /// second check come back over limit and the message was never shown.
    @Test
    func testFrequencyBudgetIsChargedOncePerExecution() async throws {
        let checker = TestFrequencyChecker()
        checker.checkAndIncrementBlock = { checker.checkAndIncrementCount <= 1 }
        await self.frequencyLimits.setCheckerBlock { _ in checker }

        try await self.engine.upsertSchedules([
            schedule("freq-a", sharedID: "freq-group", frequencyConstraintIDs: ["once-a-day"])
        ])

        await self.engine.start()
        await emitExecutionTrigger("freq-a", triggerID: "trigger-a")

        for _ in 0..<150 {
            if self.runner.runs >= 1 { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(self.runner.runs == 1)
        #expect(checker.checkAndIncrementCount == 1)
    }

    /// The drain validates a schedule microseconds before dispatching it, but a
    /// pooled one then waits on the group — for as long as a sibling's display
    /// lasts. Remote data can drop the campaign inside that window, so validity
    /// is re-checked after the wait and not only before it.
    @Test
    func testSiblingDroppedWhileWaitingDoesNotExecute() async throws {
        // Room for two, so the ledger is not what stops the second one.
        try await self.engine.upsertSchedules([
            schedule("valid-a", sharedID: "valid-group", limit: 2),
            schedule("valid-b", sharedID: "valid-group", limit: 2)
        ])

        let firstIsRunning = AirshipAtomicValue(false)
        let releaseFirst = AirshipAtomicValue(false)
        self.runner.onRunning = { index in
            guard index == 1 else { return }
            firstIsRunning.set(true)
            for _ in 0..<150 {
                if releaseFirst.value { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        await self.engine.start()
        await emitExecutionTrigger("valid-a", triggerID: "trigger-a")

        for _ in 0..<150 {
            if firstIsRunning.value { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(firstIsRunning.value)

        await emitExecutionTrigger("valid-b", triggerID: "trigger-b")

        // B is parked on the group once its validity checks stop coming: it has
        // passed everything before the wait and cannot get past A.
        var settledChecks = 0
        for _ in 0..<150 {
            let count = self.isCurrentCalls.value["valid-b", default: 0]
            if count > 0, count == settledChecks { break }
            settledChecks = count
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(settledChecks > 0)

        // Remote data drops B while it waits, then A finishes and hands over.
        self.staleScheduleIDs.update { $0.insert("valid-b") }
        releaseFirst.set(true)

        var recheckedAfterWaiting = false
        for _ in 0..<150 {
            if self.isCurrentCalls.value["valid-b", default: 0] > settledChecks {
                recheckedAfterWaiting = true
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(recheckedAfterWaiting)

        try? await Task.sleep(nanoseconds: 300_000_000)
        #expect(self.runner.runs == 1)
    }
}
