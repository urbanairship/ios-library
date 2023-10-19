/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class AirshipMeteredUsageTest: XCTestCase {
    
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let channel: AirshipChannelProtocol = TestChannel()
    private let privacyManager = AirshipPrivacyManager(
        dataStore: PreferenceDataStore(appKey: UUID().uuidString),
        defaultEnabledFeatures: [])
    private let apiClient: MeteredUsageAPIClientProtocol = MeteredTestApiClient()
    private let storage = MeteredUsageStore(appKey: "test.app.key", inMemory: true)
    private let workManager = TestWorkManager()
    private let notificationCenter = NotificationCenter()
    
    private var target: AirshipMeteredUsage!
    
    override func setUp() {
        self.target = AirshipMeteredUsage(
            dataStore: dataStore,
            channel: channel,
            privacyManager: privacyManager,
            client: apiClient,
            store: storage,
            workManager: workManager,
            notificationCenter: AirshipNotificationCenter(notificationCenter: notificationCenter)
        )
    }
    
    func testInit() {
        let worker = workManager.workers.first
        XCTAssertNotNil(worker)
        XCTAssertEqual("MeteredUsage.upload", worker?.workID)
        XCTAssertEqual(0, workManager.rateLimits.count)
        
        XCTAssertEqual(0, workManager.workRequests.count)
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        
        XCTAssertEqual(0, workManager.workRequests.count)
    }
    
    func testUpdateConfig() {
        var newConfig = MeteredUsageConfig(isEnabled: nil, initialDelay: nil, interval: nil)
        target.updateConfig(newConfig)
        XCTAssertEqual(0, workManager.workRequests.count)
        
        var limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(30, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = MeteredUsageConfig(isEnabled: nil, initialDelay: nil, interval: 2)
        target.updateConfig(newConfig)
        
        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(newConfig.interval, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = MeteredUsageConfig(isEnabled: false, initialDelay: 1, interval: 2)
        target.updateConfig(newConfig)
        
        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(newConfig.interval, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = MeteredUsageConfig(isEnabled: true, initialDelay: 1, interval: 2)
        target.updateConfig(newConfig)
        
        var workRequest = workManager.workRequests.last
        XCTAssertNotNil(workRequest)
        XCTAssertEqual(newConfig.initialDelay, workRequest?.initialDelay)
        
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(newConfig.interval, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        workManager.workRequests.removeAll()
        
        newConfig = MeteredUsageConfig(isEnabled: false, initialDelay: 1, interval: 2)
        target.updateConfig(newConfig)
        
        XCTAssertEqual(0, workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(newConfig.interval, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
        
        newConfig = MeteredUsageConfig(isEnabled: true, initialDelay: nil, interval: 2)
        target.updateConfig(newConfig)
        
        workRequest = workManager.workRequests.last
        XCTAssertNotNil(workRequest)
        XCTAssertEqual(15, workRequest?.initialDelay)
        
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        XCTAssertNotNil(limit)
        
        XCTAssertEqual(newConfig.interval, limit?.timeInterval)
        XCTAssertEqual(1, limit?.rate)
    }
    
    func testManagerUploadsDataOnBackground() {
        XCTAssertEqual(0, workManager.workRequests.count)
        
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(0, workManager.workRequests.count)
        
        target.updateConfig(MeteredUsageConfig(isEnabled: true, initialDelay: nil, interval: nil))
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        let work = workManager.workRequests.last
        
        XCTAssertNotNil(work)
        XCTAssertEqual("MeteredUsage.upload", work?.workID)
        XCTAssertEqual(0, work?.initialDelay)
    }
    
    func testEventStoreTheEventAndSendsData() async throws {
        privacyManager.enabledFeatures = [.analytics]
        
        target.updateConfig(MeteredUsageConfig(isEnabled: true, initialDelay: 1, interval: nil))
        workManager.workRequests.removeAll()
        
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            type: .InAppExperienceImpresssion,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: Date(),
            contactId: "test-contact-id"
        )
        
        XCTAssertEqual(0, workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        XCTAssertEqual(0, storedEvents.count)
        let expectation = XCTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        XCTAssertEqual(1, workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        XCTAssertEqual(event, storedEvent)
    }
    
    func testEventStoreStripsDataIfAnalyticsDisabled() async throws {
        
        target.updateConfig(MeteredUsageConfig(isEnabled: true, initialDelay: 1, interval: nil))
        workManager.workRequests.removeAll()
        
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            type: .InAppExperienceImpresssion,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: Date(),
            contactId: "test-contact-id"
        )
        
        XCTAssertEqual(0, workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        XCTAssertEqual(0, storedEvents.count)
        let expectation = XCTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        XCTAssertEqual(1, workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        XCTAssertNotNil(storedEvent)
        XCTAssertNotEqual(storedEvent, event)
        XCTAssertEqual(storedEvent, event.withDisabledAnalytics())
    }
    
    func testEventStripDataOnDisabledAnalytics() {
        let timeStamp = Date()
        let event = AirshipMeteredUsageEvent(
            eventID: "test.id",
            entityID: "story.id",
            type: .InAppExperienceImpresssion,
            product: "Story",
            reportingContext: try! AirshipJSON.wrap("context"),
            timestamp: timeStamp,
            contactId: "test-contact-id"
        )
            .withDisabledAnalytics()
        
        XCTAssertEqual(event.eventID, "test.id")
        XCTAssertEqual(event.type, .InAppExperienceImpresssion)
        XCTAssertEqual(event.product, "Story")
        XCTAssertNil(event.entityID)
        XCTAssertNil(event.reportingContext)
        XCTAssertNil(event.timestamp)
        XCTAssertNil(event.contactId)
    }
    
    func testScheduleWorkRespectsConfig() {
        
        XCTAssertEqual(0, workManager.workRequests.count)
        target.scheduleWork()
        XCTAssertEqual(0, workManager.workRequests.count)
        
        target.updateConfig(MeteredUsageConfig(isEnabled: true, initialDelay: 1, interval: 2))
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
        target.scheduleWork(initialDelay: 2, conflictPolicy: .replace)
        
        lastWork = workManager.workRequests.last
        XCTAssertNotNil(lastWork)
        XCTAssertEqual("MeteredUsage.upload", lastWork?.workID)
        XCTAssertEqual(2, lastWork?.initialDelay)
        XCTAssertEqual(true, lastWork?.requiresNetwork)
        XCTAssertEqual(AirshipWorkRequestConflictPolicy.replace, lastWork?.conflictPolicy)
    }
}

final class MeteredTestApiClient: MeteredUsageAPIClientProtocol {
    
    func uploadEvents(_ events: [AirshipCore.AirshipMeteredUsageEvent],
                      channelID: String?) async throws -> AirshipCore.AirshipHTTPResponse<Void> {
        
        
        return .init(result: nil, statusCode: 200, headers: [:])
    }
}
