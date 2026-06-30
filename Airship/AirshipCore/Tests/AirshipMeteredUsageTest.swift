/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AirshipMeteredUsageTest {
    
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let channel: TestChannel = TestChannel()
    private let contact: TestContact = TestContact()

    private let privacyManager: TestPrivacyManager
    private let apiClient: MeteredUsageAPIClientProtocol = MeteredTestApiClient()
    private let storage = MeteredUsageStore(appKey: "test.app.key", inMemory: true)
    private let workManager = TestWorkManager()
    private let config: RuntimeConfig = RuntimeConfig.testConfig()
    private let target: DefaultAirshipMeteredUsage

    init() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config:self.config,
            defaultEnabledFeatures:[]
        )

        self.target = DefaultAirshipMeteredUsage(
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
    
    @Test
    func testInit() {
        let worker = workManager.workers.first
        #expect(worker != nil)
        #expect("MeteredUsage.upload" == worker?.workID)

        // should set a default rate limit from the config
        #expect(1 == workManager.rateLimits.count)
        #expect(0 == workManager.workRequests.count)
    }

    @Test
    func testUpdateConfig() async {
        var newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: nil, initialDelayMilliseconds: nil, intervalMilliseconds: nil)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
        #expect(0 == workManager.workRequests.count)
        
        var limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(30 == limit?.timeInterval)
        #expect(1 == limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: nil, initialDelayMilliseconds: nil, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        #expect(0 == workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(2 == limit?.timeInterval)
        #expect(1 == limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        #expect(0 == workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(2 == limit?.timeInterval)
        #expect(1 == limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        var workRequest = workManager.workRequests.last
        #expect(workRequest != nil)
        #expect(1 == workRequest?.initialDelay)

        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(2 == limit?.timeInterval)
        #expect(1 == limit?.rate)
        
        workManager.workRequests.removeAll()
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1000, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        #expect(0 == workManager.workRequests.count)
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(2 == limit?.timeInterval)
        #expect(1 == limit?.rate)
        
        newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: nil, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

        workRequest = workManager.workRequests.last
        #expect(workRequest != nil)
        #expect(15 == workRequest?.initialDelay)
        
        limit = workManager.rateLimits["MeteredUsage.rateLimit"]
        #expect(limit != nil)
        
        #expect(2 == limit?.timeInterval)
        #expect(1 == limit?.rate)
    }
    
    @Test
    func testManagerUploadsDataOnBackground() {
        #expect(1 == workManager.backgroundWorkRequests.count)
        let work = workManager.backgroundWorkRequests.last
        #expect(work != nil)
        #expect("MeteredUsage.upload" == work?.workID)
        #expect(0 == work?.initialDelay)
    }
    
    @Test
    func testEventStoreTheEventAndSendsData() async throws {
        privacyManager.enabledFeatures = [.analytics]

        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

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
        
        #expect(0 == workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        #expect(0 == storedEvents.count)
        let expectation = AirshipTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        try await self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        #expect(1 == workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        #expect(event == storedEvent)
    }

    @Test
    func testAddEventConfigDisabled() async throws {
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: false, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

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
        #expect(0 == workManager.workRequests.count)

        let events = try await storage.getEvents()
        #expect(events.isEmpty)
    }

    @Test
    func testEventStoreStripsDataIfAnalyticsDisabled() async throws {
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
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
        
        #expect(0 == workManager.workRequests.count)
        let storedEvents = try await storage.getEvents()
        #expect(0 == storedEvents.count)
        let expectation = AirshipTestExpectation(description: "adding new event")
        workManager.onNewWorkRequestAdded = { _ in
            expectation.fulfill()
        }
        
        try await self.target.addEvent(event)
        
        await fulfillment(of: [expectation], timeout: 30)
        #expect(1 == workManager.workRequests.count)
        
        let storedEvent = try await storage.getEvents().first
        #expect(storedEvent != nil)
        #expect(storedEvent != event)
        #expect(storedEvent == event.withDisabledAnalytics())
    }

    @Test
    func testContactIDAddedIfNotSet() async throws {
        self.contact.contactID = "from-contact"

        privacyManager.enableFeatures(.analytics)
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: nil)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))

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
        #expect(fromStore.contactID == "test-contact-id")

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
        #expect(fromStore.contactID == "from-contact")

    }

    @Test
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
        
        #expect(event.eventID == "test.id")
        #expect(event.usageType == .inAppExperienceImpression)
        #expect(event.product == "Story")
        #expect(event.entityID == nil)
        #expect(event.reportingContext == nil)
        #expect(event.timestamp == nil)
        #expect(event.contactID == nil)
    }
    
    @Test
    func testScheduleWorkRespectsConfig() async {
        #expect(0 == workManager.workRequests.count)
        target.scheduleWork()
        #expect(0 == workManager.workRequests.count)
        
        let newConfig = RemoteConfig.MeteredUsageConfig(isEnabled: true, initialDelayMilliseconds: 1, intervalMilliseconds: 2000)
        config.updateRemoteConfig(RemoteConfig(meteredUsageConfig: newConfig))
        workManager.workRequests.removeAll()
        target.scheduleWork()
        
        var lastWork = workManager.workRequests.last
        #expect(lastWork != nil)
        #expect("MeteredUsage.upload" == lastWork?.workID)
        #expect(0 == lastWork?.initialDelay)
        #expect(true == lastWork?.requiresNetwork)
        #expect(AirshipWorkRequestConflictPolicy.keepIfNotStarted == lastWork?.conflictPolicy)
        
        workManager.workRequests.removeAll()
        target.scheduleWork(initialDelay: 2)

        lastWork = workManager.workRequests.last
        #expect(lastWork != nil)
        #expect("MeteredUsage.upload" == lastWork?.workID)
        #expect(2 == lastWork?.initialDelay)
        #expect(true == lastWork?.requiresNetwork)
        #expect(AirshipWorkRequestConflictPolicy.keepIfNotStarted == lastWork?.conflictPolicy)
        
        workManager.workRequests.removeAll()
        target.scheduleWork(initialDelay: 2)

        lastWork = workManager.workRequests.last
        #expect(lastWork != nil)
        #expect("MeteredUsage.upload" == lastWork?.workID)
        #expect(2 == lastWork?.initialDelay)
        #expect(true == lastWork?.requiresNetwork)
        #expect(AirshipWorkRequestConflictPolicy.keepIfNotStarted == lastWork?.conflictPolicy)
    }
}

fileprivate final class MeteredTestApiClient: MeteredUsageAPIClientProtocol {
    
    func uploadEvents(_ events: [AirshipCore.AirshipMeteredUsageEvent],
                      channelID: String?) async throws -> AirshipCore.AirshipHTTPResponse<Void> {
        
        
        return .init(result: nil, statusCode: 200, headers: [:])
    }
}
