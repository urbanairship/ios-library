/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
@testable import AirshipCore

final class AutomationEventFeedTest: XCTestCase, @unchecked Sendable {
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private var subject: AutomationEventFeed!
    private let analyticsFeed: AirshipAnalyticsFeed = AirshipAnalyticsFeed() { true }
    private let stateTracker: TestAppStateTracker = TestAppStateTracker()

    var iterator: AsyncStream<AutomationEvent>.Iterator!
    
    override func setUp() async throws {
        let metrics = TestApplicationMetrics()
        metrics.versionUpdated = true
        
        subject = await AutomationEventFeed(applicationMetrics: metrics, applicationStateTracker: stateTracker, analyticsFeed: analyticsFeed)

        iterator = await subject.feed.makeAsyncIterator()
    }
    
    func testFirstAttachProducesInitAndVersionUpdated() async throws {
        await subject.attach()

        let events = await takeNext(count: 2)
        
        let state = TriggerableState(versionUpdated: "test")
        
        XCTAssertEqual([AutomationEvent.event(type: .appInit), AutomationEvent.stateChanged(state: state)], events)
    }
    
    func testSubsequentAttachEmitsNoEvents() async throws {
        await subject.attach()
        var events = await takeNext(count: 3)

        await subject.attach()
        events = await takeNext()
        XCTAssert(events.isEmpty)
        
        await subject.detach().attach()
        events = await takeNext()
        
        XCTAssert(events.isEmpty)
    }
    
    @MainActor
    func testSupportedEvents() async throws {
        subject.attach()
        await takeNext(count: 3)

        stateTracker.currentState = .active
        var events = await takeNext(count: 2)
        XCTAssertEqual(AutomationEvent.event(type: .foreground), events.first)
        verifyStateChange(event: events.last!, foreground: true, versionUpdated: "test")

        stateTracker.currentState = .background
        events = await takeNext(count: 2)
        XCTAssertEqual(AutomationEvent.event(type: .background), events.first)
        verifyStateChange(event: events.last!, foreground: false, versionUpdated: "test")

        let trackScreenName = "test-screen"
        await analyticsFeed.notifyEvent(.screen(screen: trackScreenName))
        var event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .screen, data: .string(trackScreenName)), event)
        
        await analyticsFeed.notifyEvent(.analytics(eventType: .regionEnter, body: .string("some region data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .regionEnter, data: .string("some region data")), event)

        await analyticsFeed.notifyEvent(.analytics(eventType: .regionExit, body: .string("some region data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .regionExit, data: .string("some region data")), event)

        await analyticsFeed.notifyEvent(.analytics(eventType: .customEvent, body: .string("some data"), value: 100))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .customEventCount, data: .string("some data"), value: 1), event)
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .customEventValue, data: .string("some data"), value: 100), event)
        

        await analyticsFeed.notifyEvent(.analytics(eventType: .featureFlagInteraction, body: .string("some data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .featureFlagInteraction, data: .string("some data")), event)
    }
    
    func testAnalyticFeedEvents() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        let eventMap: [EventType: [EventAutomationTriggerType]] = [
            .customEvent: [.customEventCount, .customEventValue],
            .regionExit: [.regionExit],
            .regionEnter: [.regionEnter],
            .featureFlagInteraction: [.featureFlagInteraction],
            .inAppDisplay: [.inAppDisplay],
            .inAppResolution: [.inAppResolution],
            .inAppButtonTap: [.inAppButtonTap],
            .inAppPermissionResult: [.inAppPermissionResult],
            .inAppFormDisplay: [.inAppFormDisplay],
            .inAppFormResult: [.inAppFormResult],
            .inAppGesture: [.inAppGesture],
            .inAppPagerCompleted: [.inAppPagerCompleted],
            .inAppPagerSummary: [.inAppPagerSummary],
            .inAppPageSwipe: [.inAppPageSwipe],
            .inAppPageView: [.inAppPageView],
            .inAppPageAction: [.inAppPageAction]
        ]
        
        for eventType in EventType.allCases {
            guard let expected = eventMap[eventType] else { continue }
            
            let data = AirshipJSON.string(UUID().uuidString)
            await analyticsFeed.notifyEvent(.analytics(eventType: eventType, body: data))
            
            for expectedTriggerType in expected {
                let event = await takeNext().first
                XCTAssertEqual(AutomationEvent.event(type: expectedTriggerType, data: data, value: 1.0), event)
            }
        }
    }
    
    func testScreenEvent() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        await analyticsFeed.notifyEvent(.screen(screen: "foo"))
        let event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .screen, data: .string("foo"), value: 1.0), event)
    }
    
    func testCustomEventValues() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        await analyticsFeed.notifyEvent(.analytics(eventType: .customEvent, body: .null, value: 10))
        
        var event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .customEventCount, data: .null, value: 1.0), event)
        
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.event(type: .customEventValue, data: .null, value: 10.0), event)
    }
    
    func testNoEventsIfNotAttached() async throws {
        var events = await takeNext()
        XCTAssert(events.isEmpty)
        
        await self.analyticsFeed.notifyEvent(.screen(screen: "foo"))
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }
    
    func testNoEventsAfterDetach() async throws {
        await self.subject.attach()
        var events = await takeNext(count: 3)
        XCTAssert(events.count > 0)
        
        await subject.detach()

        await self.analyticsFeed.notifyEvent(.screen(screen: "foo"))
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }

    func verifyStateChange(event: AutomationEvent, foreground: Bool, versionUpdated: String?, line: UInt = #line) {
        guard case .stateChanged(let state) = event else {
            XCTFail("invalid event", line: line)
            return
        }

        if (foreground) {
            XCTAssertNotNil(state.appSessionID)
        } else {
            XCTAssertNil(state.appSessionID)
        }
        XCTAssertEqual(versionUpdated, state.versionUpdated)
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



class TestApplicationMetrics: ApplicationMetricsProtocol, @unchecked Sendable {
    var currentAppVersion: String? = "test"


    var versionUpdated = false

    var isAppVersionUpdated: Bool { return versionUpdated }
}
