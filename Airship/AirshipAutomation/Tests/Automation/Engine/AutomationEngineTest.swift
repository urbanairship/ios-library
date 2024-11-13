/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

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

final class AutomationEngineTest: XCTestCase {
    
    private var engine: AutomationEngine!
    private var dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var automationStore: AutomationStore!
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let actionPreparer: TestPreparerDelegate<AirshipJSON, AirshipJSON> = TestPreparerDelegate()
    private let messagePreparer: TestPreparerDelegate<InAppMessage, PreparedInAppMessageData> = TestPreparerDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private var privacyManager: AirshipPrivacyManager!
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
    private var runtimeConfig: RuntimeConfig?

    private var scheduleConditionsChangedNotifier: TestScheduleConditionsChangedNotifier!

    @MainActor
    override func setUp() async throws {
        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            config:  RuntimeConfig(
                config: AirshipConfig(),
                dataStore: self.dataStore
            ),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )
        
        var config = AirshipConfig()
        config.requireInitialRemoteConfigEnabled = false
        self.runtimeConfig = RuntimeConfig(
            config: config,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
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
            config: self.runtimeConfig!,
            additionalAudienceResolver: TestAdditionalAudienceResolver()
        )
        
        let actionExecutor = ActionAutomationExecutor()
        let messageExecutor = TestInAppMessageAutomationExecutor()
        let executor = AutomationExecutor(actionExecutor: actionExecutor, messageExecutor: messageExecutor, remoteDataAccess: remoteDataAccess)
        let triggersProcessor = AutomationTriggerProcessor(store: automationStore)
        
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
            delayProcessor: delayProcessor
        )
    }
    
    override func tearDown() async throws {
        await self.engine.stop()
    }
    
    func testStart() async throws {
        await self.engine.start()
        let startTask = await self.engine.startTask
        let listenTask = await self.engine.listenerTask
        
        XCTAssertNotNil(startTask)
        XCTAssertNotNil(listenTask)
    }
    
    func testStop() async throws {
        await self.engine.stop()
        let startTask = await self.engine.startTask
        let listenTask = await self.engine.listenerTask
        XCTAssertNil(startTask)
        XCTAssertNil(listenTask)
    }
    
    @MainActor
    func testSetEnginePaused() async throws {
        self.engine.setEnginePaused(true)
        XCTAssertTrue(self.engine.isEnginePaused.value)
    }
    
    @MainActor
    func testSetExecutionPaused() async throws {
        let onNotifyExpectation = expectation(description: "Schedule conditions changed notifiers should be notified when pause state changes.")

        self.scheduleConditionsChangedNotifier.onNotify = {
            onNotifyExpectation.fulfill()
        }

        self.engine.setExecutionPaused(true)
        XCTAssertTrue(self.engine.isExecutionPaused.value)


        self.engine.setExecutionPaused(false)
        XCTAssertFalse(self.engine.isExecutionPaused.value)

        await fulfillment(of: [onNotifyExpectation], timeout: 1)
    }
    
    func testStopSchedules() async throws {
        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        var schedule = try await self.engine.getSchedule(identifier: "test")
        XCTAssertNotNil(schedule)
        try await self.engine.stopSchedules(identifiers: ["test"])
        schedule = try await self.engine.getSchedule(identifier: "test")
        XCTAssertNil(schedule)
    }
    
    func testUpsertSchedules() async throws {
        var schedule = try await self.engine.getSchedule(identifier: "test")
        XCTAssertNil(schedule)
        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        schedule = try await self.engine.getSchedule(identifier: "test")
        XCTAssertNotNil(schedule)
    }
    
    func testCancelSchedule() async throws {
        try await self.engine.upsertSchedules([AutomationSchedule(identifier: "test", triggers: [], data: .inAppMessage(
            InAppMessage(
                name: "test",
                displayContent: .custom(.string("test"))
            )))])
        try await self.engine.cancelSchedules(identifiers: ["test"])
        let schedule = try await self.engine.getSchedule(identifier: "test")
        XCTAssertNil(schedule)
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
