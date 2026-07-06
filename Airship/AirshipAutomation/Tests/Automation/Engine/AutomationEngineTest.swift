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

        self.automationStore = AutomationStore(appKey: UUID().uuidString, inMemory: true)
        self.preparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: audienceChecker,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess,
            config: self.runtimeConfig,
            additionalAudienceResolver: TestAdditionalAudienceResolver()
        )
        
        let actionExecutor = ActionAutomationExecutor()
        let messageExecutor = TestInAppMessageAutomationExecutor()
        let executor = AutomationExecutor(actionExecutor: actionExecutor, messageExecutor: messageExecutor, remoteDataAccess: remoteDataAccess)
        let triggersProcessor = AutomationTriggerProcessor(store: automationStore, history: history)
        
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
            triggersProcessor: triggersProcessor,
            delayProcessor: delayProcessor,
            eventsHistory: history
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
