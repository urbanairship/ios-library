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
