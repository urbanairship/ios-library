/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class AirshipMeteredUsageTest: XCTestCase {
    
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let channel: TestChannel = TestChannel()
    private let contact: TestContact = TestContact()

    private var privacyManager: TestPrivacyManager!
    private let apiClient: MeteredUsageAPIClientProtocol = MeteredTestApiClient()
    private let storage = MeteredUsageStore(appKey: "test.app.key", inMemory: true)
    private let workManager = TestWorkManager()
    private var config: RuntimeConfig = RuntimeConfig.testConfig()
    private var target: AirshipMeteredUsage!

    @MainActor
    override func setUp() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config:self.config,
            defaultEnabledFeatures:[]
        )

        self.target = AirshipMeteredUsage(
            config: config,
            dataStore: dataStore,
            channel: channel,
            contact: contact,
            privacyManager: privacyManager,
            client: apiClient,
            store: storage,
            workManager: workManager
        )
    }
    
    func testInit() {
        let worker = workManager.workers.first
        XCTAssertNotNil(worker)
        XCTAssertEqual("MeteredUsage.upload", worker?.workID)

        // should set a default rate limit from the config
        XCTAssertEqual(1, workManager.rateLimits.count)
        XCTAssertEqual(0, workManager.workRequests.count)
    }

    func testUpdateConfig() async {
        var newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: nil, initialDelayMilliseconds: nil, intervalMilliseconds: nil)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
        XCTAssertEqual(0, workManager.workRequests.count)
        
        var limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(30, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: nil, initialDelayMilliseconds: nil, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(2, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(2, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        var workRequest = workManager.workRequests.last
        XCTAssertNotNil(workRequest)
        XCTAssertEqual(1, workRequest?.initialDelay)

        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(2, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        workManager.workRequests.removeAll()
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(2, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: nil, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        workRequest = workManager.workRequests.last
        XCTAssertNotNil(workRequest)
        XCTAssertEqual(15, workRequest?.initialDelay)
        
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(2, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
    }
    
    func testManagerUploadsDataOnBackground() {
        XCTAssertEqual(1, workManager.backgroundWorkRequests.count)
        let work = workManager.backgroundWorkRequests.last
        XCTAssertNotNil(work)
        XCTAssertEqual("MeteredUsage.upload", work?.workID)
        XCTAssertEqual(0, work?.initialDelay)
    }
    
    func testEventStoreTheEventAndSendsData() async throws {
        privacyManager.enabledFeatures = [.analytics]

        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        workManager.workRequests.removeAll()
        
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            usageType: .inAppExperienceImpression,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: Date(),
            contactID: "test-contact-id"
        )
        
        XCTAssertEqual(0, workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        XCTAssertEqual(0, storedEvents.count)
        let expectation = XCTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        try await self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        XCTAssertEqual(1, workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        XCTAssertEqual(event, storedEvent)
    }

    func testAddEventConfigDisabled() async throws {
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        workManager.workRequests.removeAll()

        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            usageType: .inAppExperienceImpression,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: Date(),
            contactID: "test-contact-id"
        )

        try await self.target.addEvent(event)
        XCTAssertEqual(0, workManager.workRequests.count)

        let events = try await storage.getEvents()
        XCTAssertTrue(events.isEmpty)
    }

    func testEventStoreStripsDataIfAnalyticsDisabled() async throws {
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
        workManager.workRequests.removeAll()
        
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            usageType: .inAppExperienceImpression,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: Date(),
            contactID: "test-contact-id"
        )
        
        XCTAssertEqual(0, workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        XCTAssertEqual(0, storedEvents.count)
        let expectation = XCTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        try await self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        XCTAssertEqual(1, workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        XCTAssertNotNil(storedEvent)
        XCTAssertNotEqual(storedEvent, event)
        XCTAssertEqual(storedEvent, event.withDisabledAnalytics())
    }

    func testContactIDAddedIfNotSet() async throws {
        self.contact.contactID = "from-contact"

        privacyManager.enableFeatures(.analytics)
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        try await self.target.addEvent(
            AirshipMeteredUsageEvent(
                eventID: "test.id",
                entityID: "story.id",
                usageType: .inAppExperienceImpression,
                product: "Story",
                reportingContext: try! AirshipJSON.wrap("context"),
                timestamp: Date(),
                contactID: "test-contact-id"
            )
        )

        var fromStore = try await storage.getEvents().first!
        XCTAssertEqual(fromStore.contactID, "test-contact-id")

        try await self.target.addEvent(
            AirshipMeteredUsageEvent(
                eventID: "test.id",
                entityID: "story.id",
                usageType: .inAppExperienceImpression,
                product: "Story",
                reportingContext: try! AirshipJSON.wrap("context"),
                timestamp: Date(),
                contactID: nil
            )
        )

        fromStore = try await storage.getEvents().first!
        XCTAssertEqual(fromStore.contactID, "from-contact")

    }

    func testEventStripDataOnDisabledAnalytics() {
        let timeStamp = Date()
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            usageType: .inAppExperienceImpression,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: timeStamp,
            contactID: "test-contact-id"
        )
            .withDisabledAnalytics()
        
        XCTAssertEqual(event.eventID, "test.id")
        XCTAssertEqual(event.usageType, .inAppExperienceImpression)
        XCTAssertEqual(event.product, "Story")
        XCTAssertNil(event.entityID)
        XCTAssertNil(event.reportingContext)
        XCTAssertNil(event.timestamp)
        XCTAssertNil(event.contactID)
    }
    
    func testScheduleWorkRespectsConfig() async {
        XCTAssertEqual(0, workManager.workRequests.count)
        target.scheduleWork()
        XCTAssertEqual(0, workManager.workRequests.count)
        
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: 2000)
        await config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
        workManager.workRequests.removeAll()
        target.scheduleWork()
        
        var lastWork = workManager.workRequests.last
        XCTAssertNotNil(lastWork)
        XCTAssertEqual("MeteredUsage.upload", lastWork?.workID)
        XCTAssertEqual(0, lastWork?.initialDelay)
        XCTAssertEqual(true, lastWork?.requiresNetwork)
        XCTAssertEqual(AirshipWorkRequestConflictPolicy.keepIfNotStarted, lastWork?.conflictPolicy)
        
        workManager.workRequests.removeAll()
        target.scheduleWork(initialDelay: 2)

        lastWork = workManager.workRequests.last
        XCTAssertNotNil(lastWork)
        XCTAssertEqual("MeteredUsage.upload", lastWork?.workID)
        XCTAssertEqual(2, lastWork?.initialDelay)
        XCTAssertEqual(true, lastWork?.requiresNetwork)
        XCTAssertEqual(AirshipWorkRequestConflictPolicy.keepIfNotStarted, lastWork?.conflictPolicy)
        
        workManager.workRequests.removeAll()
        target.scheduleWork(initialDelay: 2)

        lastWork = workManager.workRequests.last
        XCTAssertNotNil(lastWork)
        XCTAssertEqual("MeteredUsage.upload", lastWork?.workID)
        XCTAssertEqual(2, lastWork?.initialDelay)
        XCTAssertEqual(true, lastWork?.requiresNetwork)
        XCTAssertEqual(AirshipWorkRequestConflictPolicy.keepIfNotStarted, lastWork?.conflictPolicy)
    }
}

final class MeteredTestApiClient: MeteredUsageAPIClientProtocol {
    
    func uploadEvents(_ events: [AirshipCore.AirshipMeteredUsageEvent],
                      channelID: String?) async throws -> AirshipCore.AirshipHTTPResponse<Void> {
        
        
        return .init(result: nil, statusCode: 200, headers: [:])
    }
}
