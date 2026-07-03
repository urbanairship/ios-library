/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
@testable import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

struct AutomationEventFeedTest: @unchecked Sendable {
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private var subject: AutomationEventFeed!
    private let analyticsFeed: AirshipAnalyticsFeed = AirshipAnalyticsFeed() { true }
    private let stateTracker: TestAppStateTracker = TestAppStateTracker()

    var iterator: AsyncStream<AutomationEvent>.Iterator!
    
    init() async throws {
        let metrics = TestApplicationMetrics()
        metrics.versionUpdated = true
        
        subject = await AutomationEventFeed(applicationMetrics: metrics, applicationStateTracker: stateTracker, analyticsFeed: analyticsFeed)

        iterator = subject.feed.makeAsyncIterator()
    }
    
    @Test
    func testFirstAttachProducesInitAndVersionUpdated() async throws {
        await subject.attach()

        let events = await takeNext(count: 2)
        
        let state = TriggerableState(versionUpdated: "test")
        
        #expect([AutomationEvent.event(type: .appInit), AutomationEvent.stateChanged(state: state)] == events)
    }
    
    @Test
    func testSubsequentAttachEmitsNoEvents() async throws {
        await subject.attach()
        var events = await takeNext(count: 3)

        await subject.attach()
        events = await takeNext()
        #expect(events.isEmpty)
        
        await subject.detach().attach()
        events = await takeNext()
        
        #expect(events.isEmpty)
    }
    
    @Test
    @MainActor
    func testSupportedEvents() async throws {
        subject.attach()
        await takeNext(count: 3)

        stateTracker.currentState = .active
        var events = await takeNext(count: 2)
        #expect(AutomationEvent.event(type: .foreground) == events.first)
        verifyStateChange(event: events.last!, foreground: true, versionUpdated: "test")

        stateTracker.currentState = .background
        events = await takeNext(count: 2)
        #expect(AutomationEvent.event(type: .background) == events.first)
        verifyStateChange(event: events.last!, foreground: false, versionUpdated: "test")

        let trackScreenName = "test-screen"
        await analyticsFeed.notifyEvent(.screen(screen: trackScreenName))
        var event = await takeNext().first
        #expect(AutomationEvent.event(type: .screen, data: .string(trackScreenName)) == event)
        
        await analyticsFeed.notifyEvent(.analytics(eventType: .regionEnter, body: "some region data"))
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .regionEnter, data: "some region data") == event)

        await analyticsFeed.notifyEvent(.analytics(eventType: .regionExit, body: "some region data"))
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .regionExit, data: "some region data") == event)

        await analyticsFeed.notifyEvent(.analytics(eventType: .customEvent, body: "some data", value: 100))
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .customEventCount, data: "some data", value: 1) == event)
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .customEventValue, data: "some data", value: 100) == event)
        

        await analyticsFeed.notifyEvent(.analytics(eventType: .featureFlagInteraction, body: "some data"))
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .featureFlagInteraction, data: "some data") == event)
    }
    
    @Test
    func testAnalyticFeedEvents() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        let eventMap: [AirshipEventType: [EventAutomationTriggerType]] = [
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
        
        for eventType in AirshipEventType.allCases {
            guard let expected = eventMap[eventType] else { continue }
            
            let data = AirshipJSON.string(UUID().uuidString)
            await analyticsFeed.notifyEvent(.analytics(eventType: eventType, body: data))
            
            for expectedTriggerType in expected {
                let event = await takeNext().first
                #expect(AutomationEvent.event(type: expectedTriggerType, data: data, value: 1.0) == event)
            }
        }
    }
    
    @Test
    func testScreenEvent() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        await analyticsFeed.notifyEvent(.screen(screen: "foo"))
        let event = await takeNext().first
        #expect(AutomationEvent.event(type: .screen, data: "foo", value: 1.0) == event)
    }
    
    @Test
    func testCustomEventValues() async throws {
        await subject.attach()
        await takeNext(count: 3)
        
        await analyticsFeed.notifyEvent(.analytics(eventType: .customEvent, body: .null, value: 10))
        
        var event = await takeNext().first
        #expect(AutomationEvent.event(type: .customEventCount, data: .null, value: 1.0) == event)
        
        event = await takeNext().first
        #expect(AutomationEvent.event(type: .customEventValue, data: .null, value: 10.0) == event)
    }
    
    @Test
    func testNoEventsIfNotAttached() async throws {
        var events = await takeNext()
        #expect(events.isEmpty)
        
        await self.analyticsFeed.notifyEvent(.screen(screen: "foo"))
        events = await takeNext()
        #expect(events.isEmpty)
    }
    
    @Test
    func testNoEventsAfterDetach() async throws {
        await self.subject.attach()
        var events = await takeNext(count: 3)
        #expect(events.count > 0)
        
        await subject.detach()

        await self.analyticsFeed.notifyEvent(.screen(screen: "foo"))
        events = await takeNext()
        #expect(events.isEmpty)
    }

    func verifyStateChange(event: AutomationEvent, foreground: Bool, versionUpdated: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        guard case .stateChanged(let state) = event else {
            Issue.record("invalid event", sourceLocation: sourceLocation)
            return
        }

        if (foreground) {
            #expect(state.appSessionID != nil, sourceLocation: sourceLocation)
        } else {
            #expect(state.appSessionID == nil, sourceLocation: sourceLocation)
        }
        #expect(versionUpdated == state.versionUpdated, sourceLocation: sourceLocation)
    }

    @discardableResult
    private func takeNext(count: UInt = 1, timeout: Int = 5) async -> [AutomationEvent] {
        
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
        
        let result = await collectTask.result.get()
        cancel.cancel()
        return result
    }
}



class TestApplicationMetrics: ApplicationMetricsProtocol, @unchecked Sendable {
    var currentAppVersion: String? = "test"


    var versionUpdated = false

    var isAppVersionUpdated: Bool { return versionUpdated }
}
