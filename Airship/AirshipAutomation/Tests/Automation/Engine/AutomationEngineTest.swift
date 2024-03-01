/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

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

    override func setUp() async throws {
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config:  RuntimeConfig(
                config: AirshipConfig(),
                dataStore: self.dataStore
            ),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )
        self.automationStore = AutomationStore(appKey: UUID().uuidString, inMemory: true)
        self.preparer = await AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: audienceChecker,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess
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

        let analyticsFeed = AirshipAnalyticsFeed()
        let scheduleConditionsChangedNotifier = ScheduleConditionsChangedNotifier()
        let eventFeed = await AutomationEventFeed(applicationMetrics: metrics, applicationStateTracker: AppStateTracker.shared, analyticsFeed: analyticsFeed)
        let analytics = TestAnalytics()
        let delayProcessor = await AutomationDelayProcessor(analytics: analytics)
        
        self.engine = AutomationEngine(store: self.automationStore, executor: executor, preparer: self.preparer, scheduleConditionsChangedNotifier: scheduleConditionsChangedNotifier, eventFeed: eventFeed, triggersProcessor: triggersProcessor, delayProcessor: delayProcessor)

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
        self.engine.setExecutionPaused(true)
        XCTAssertTrue(self.engine.isExecutionPaused.value)
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

fileprivate final class TestAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol, @unchecked Sendable {
      
    @MainActor
    var onMake: ((String, String?, String?, InAppMessage, AirshipJSON?, AirshipJSON?) -> InAppMessageAnalyticsProtocol)?


    @MainActor
    func setOnMake(onMake: @escaping @Sendable (String, String?, String?, InAppMessage, AirshipJSON?, AirshipJSON?) -> InAppMessageAnalyticsProtocol) {
        self.onMake = onMake
    }
    @MainActor
    func makeAnalytics(
        scheduleID: String,
        productID: String?,
        contactID: String?,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol {
        return self.onMake!(scheduleID, productID, contactID, message, campaigns, reportingContext)
    }
}
