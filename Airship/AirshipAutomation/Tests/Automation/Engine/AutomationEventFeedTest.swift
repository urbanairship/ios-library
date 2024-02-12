/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationEventFeedTest: XCTestCase, @unchecked Sendable {
    let date = UATestDate(offset: 0, dateOverride: Date())
    let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    let notificaitonCenter = NotificationCenter()
    var subject: AutomationEventFeed!
    let airship = TestAirshipInstance()
    
    var iterator: AsyncStream<AutomationEvent>.Iterator!
    
    override func setUp() async throws {
        let config = RuntimeConfig(config: AirshipConfig(), dataStore: datastore)

        let privacyManager = await AirshipPrivacyManager(
            dataStore: self.datastore,
            config: config,
            defaultEnabledFeatures: .all
        )
        let metrics = TestApplicationMetrics(dataStore: self.datastore, privacyManager: privacyManager, appVersion: "test")
        metrics.versionUpdated = true
        
        let airshipNotification = AirshipNotificationCenter(notificationCenter: notificaitonCenter)
        subject = await AutomationEventFeed(metrics: metrics, notificationCenter: airshipNotification)

        airship.applicationMetrics = metrics
        airship.components = [TestAnalytics()]
        airship.makeShared()
        
        iterator = await subject.feed.makeAsyncIterator()
    }
    
    override func tearDown() async throws {
        TestAirshipInstance.clearShared()
    }
    
    func testFirstAttachProducesInitAndVersionUpdated() async throws {
        await subject.attach()

        let events = await takeNext(count: 2)
        
        let state = TriggerableState(versionUpdated: "test")
        
        XCTAssertEqual([AutomationEvent.appInit, AutomationEvent.stateChanged(state: state)], events)
    }
    
    func testSubsequentAttachEmitsNoEvents() async throws {
        await subject.attach()
        var events = await takeNext(count: 2)
        
        await subject.attach()
        events = await takeNext()
        XCTAssert(events.isEmpty)
        
        await subject.detach().attach()
        events = await takeNext()
        
        XCTAssert(events.isEmpty)
    }
    
    func testSupportedEvents() async throws {
        await subject.attach()
        await takeNext(count: 2)
        
        notificaitonCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        var events = await takeNext(count: 2)
        XCTAssertEqual(AutomationEvent.foreground, events.first)
        
        notificaitonCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        events = await takeNext(count: 2)
        XCTAssertEqual(AutomationEvent.background, events.first)
        XCTAssertEqual(AutomationEvent.stateChanged(state: TriggerableState(versionUpdated: "test")), events.last)
        
        let trackScreenName = "test-screen"
        notificaitonCenter.post(name: AirshipAnalytics.screenTracked, object: nil, userInfo: [AirshipAnalytics.screenKey: trackScreenName])
        var event = await takeNext().first
        XCTAssertEqual(AutomationEvent.screenView(name: trackScreenName), event)
        
        let regionIdEnter = "reg-id"
        let regionEventEnter = RegionEvent(regionID: regionIdEnter, source: "unit-test", boundaryEvent: .enter)!
        notificaitonCenter.post(name: AirshipAnalytics.regionEventAdded, object: nil, userInfo: [AirshipAnalytics.eventKey: regionEventEnter])
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.regionEnter(regionId: regionIdEnter), event)
        
        let regionIdExit = "reg-id-exit"
        let regionEventExit = RegionEvent(regionID: regionIdExit, source: "unit-test", boundaryEvent: .exit)!
        notificaitonCenter.post(name: AirshipAnalytics.regionEventAdded, object: nil, userInfo: [AirshipAnalytics.eventKey: regionEventExit])
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.regionExit(regionId: regionIdExit), event)
        
        let customEvent = CustomEvent(name: "feed-test", value: 1.23)
        customEvent.eventName = "test-name"
        notificaitonCenter.post(name: AirshipAnalytics.customEventAdded, object: nil, userInfo: [AirshipAnalytics.eventKey: customEvent])
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.customEvent(
            data: try AirshipJSON.wrap([
                "event_name": "test-name",
                "event_value": 1.23,
                "properties": [:]
            ]),
            value: 1.23), event)
        
        let ffInterractionEvent = CustomEvent(name: "ff-interracted")
        notificaitonCenter.post(name: AirshipAnalytics.featureFlagInterracted, object: nil, userInfo: [AirshipAnalytics.eventKey: ffInterractionEvent])
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.featureFlagInterracted(
            data: try AirshipJSON.wrap(["event_name": "ff-interracted", "properties": [:]])
        ), event)
    }
    
    func testNoEventsIfNotAttached() async throws {
        var events = await takeNext()
        XCTAssert(events.isEmpty)
        
        notificaitonCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }
    
    func testNoEventsAfterDetauch() async throws {
        await self.subject.attach()
        var events = await takeNext(count: 2)
        XCTAssert(events.count > 0)
        
        await subject.detach()
        notificaitonCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }
    
    @discardableResult
    private func takeNext(count: UInt = 1, timeout: Int = 1) async -> [AutomationEvent] {
        
        let collectTask = Task {
            var result: [AutomationEvent] = []
            var iterator = await self.subject.feed.makeAsyncIterator()
            while result.count < count, !Task.isCancelled {
                if let next = await iterator.next() {
                    result.append(next)
                }
            }
            
            return result
        }
        
        let cancel = DispatchWorkItem {
            collectTask.cancel()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeout), execute: cancel)
        
        do {
            let result = try await collectTask.result.get()
            cancel.cancel()
            return result
        } catch {
            print("failed to get results \(error)")
            return []
        }
    }
}
