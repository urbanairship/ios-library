/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationEventFeedTest: XCTestCase, @unchecked Sendable {
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private var subject: AutomationEventFeed!
    private let analyticsFeed: AirshipAnalyticsFeed = AirshipAnalyticsFeed()
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
        
        XCTAssertEqual([AutomationEvent.appInit, AutomationEvent.stateChanged(state: state)], events)
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
        XCTAssertEqual(AutomationEvent.foreground, events.first)
        verifyStateChange(event: events.last!, foreground: true, versionUpdated: "test")

        stateTracker.currentState = .background
        events = await takeNext(count: 2)
        XCTAssertEqual(AutomationEvent.background, events.first)
        verifyStateChange(event: events.last!, foreground: false, versionUpdated: "test")

        let trackScreenName = "test-screen"
        analyticsFeed.notifyEvent(.screenChange(screen: trackScreenName))
        var event = await takeNext().first
        XCTAssertEqual(AutomationEvent.screenView(name: trackScreenName), event)
        
        analyticsFeed.notifyEvent(.regionEnter(body: .string("some region data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.regionEnter(data: .string("some region data")), event)

        analyticsFeed.notifyEvent(.regionExit(body: .string("some region data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.regionExit(data: .string("some region data")), event)

        analyticsFeed.notifyEvent(.customEvent(body: .string("some data"), value: 100.0))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.customEvent(data: .string("some data"), value: 100.0), event)

        analyticsFeed.notifyEvent(.featureFlagInteraction(body: .string("some data")))
        event = await takeNext().first
        XCTAssertEqual(AutomationEvent.featureFlagInterracted(data: .string("some data")), event)
    }
    
    func testNoEventsIfNotAttached() async throws {
        var events = await takeNext()
        XCTAssert(events.isEmpty)
        
        self.analyticsFeed.notifyEvent(.screenChange(screen: "foo"))
        events = await takeNext()
        XCTAssert(events.isEmpty)
    }
    
    func testNoEventsAfterDetach() async throws {
        await self.subject.attach()
        var events = await takeNext(count: 3)
        XCTAssert(events.count > 0)
        
        await subject.detach()

        self.analyticsFeed.notifyEvent(.screenChange(screen: "foo"))
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
