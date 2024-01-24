/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class AutomationEventFeedTest: XCTestCase, @unchecked Sendable {
    let date = UATestDate(offset: 0, dateOverride: Date())
    let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    let notificaitonCenter = NotificationCenter()
    var subject: AutomationEventFeed!
    let airship = TestAirshipInstance()
    
    var iterator: AsyncStream<AutomationEvent>.Iterator!
    
    override func setUp() async throws {
        let airshipNotification = AirshipNotificationCenter(notificationCenter: notificaitonCenter)
        subject = AutomationEventFeed(notificationCenter: airshipNotification)
        
        let privacyManager = AirshipPrivacyManager(dataStore: self.datastore, defaultEnabledFeatures: .all)
        
        let metrics = TestApplicationMetrics(dataStore: self.datastore, privacyManager: privacyManager)
        metrics.versionUpdated = true
        airship.applicationMetrics = metrics
        airship.components = [TestAnalytics()]
        airship.makeShared()
        
        iterator = subject.feed.makeAsyncIterator()
    }
    
    override func tearDown() async throws {
        TestAirshipInstance.clearShared()
    }
    
    func testFirstAttachProducesInitAndVersionUpdated() async throws {
        subject.attach()
        
        let events = await takeNext(count: 2)
        
        XCTAssertEqual([AutomationEvent.appInit, AutomationEvent.versionUpdated], events)
    }
    
    func testSubsequentAttachEmitsNoEvents() async throws {
        subject.attach()
        var events = await takeNext(count: 2)
        
        subject.attach()
        events = await takeNext()
        XCTAssert(events.isEmpty)
        
        subject.detach().attach()
        events = await takeNext()
        
        XCTAssert(events.isEmpty)
    }
    
    func testSupportedEvents() async throws {
        subject.attach()
        await takeNext(count: 2)
        
        notificaitonCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        var event = await takeNext().first
        XCTAssertEqual(AutomationEvent.foreground, event)
        
        notificaitonCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.background, event)
        
        let trackScreenName = "test-screen"
        notificaitonCenter.post(name: AirshipAnalytics.screenTracked, object: nil, userInfo: [AirshipAnalytics.screenKey: trackScreenName])
        event = await takeNext().first
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
                "event_value": 1230000.0,
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
        self.subject.attach()
        var events = await takeNext(count: 2)
        XCTAssert(events.count > 0)
        
        subject.detach()
        notificaitonCenter.post(name: AppStateTracker.didBecomeActiveNotification, object: nil)
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }
    
    @discardableResult
    private func takeNext(count: UInt = 1, timeout: Int = 1) async -> [AutomationEvent] {
        
        let collectTask = Task {
            var result: [AutomationEvent] = []
            var iterator = self.subject.feed.makeAsyncIterator()
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
