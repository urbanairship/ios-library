/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore


final class AutomationDelayProcessorTest: XCTestCase {

    private let analytics: TestAnalytics = TestAnalytics()
    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private let date: UATestDate = UATestDate()
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    private var processor: AutomationDelayProcessor!

    override func setUp() async throws {
        self.date.dateOverride = Date()
        self.processor = await AutomationDelayProcessor(
            analytics: analytics,
            appStateTracker: stateTracker,
            taskSleeper: taskSleeper,
            date: date
        )
    }

    @MainActor
    func testWaitConditions() async throws {
        let delay = AutomationDelay(
            seconds: 100.0,
            screens: ["screen1", "screen2"],
            regionID: "region1",
            appState: .foreground
        )

        let finished = AirshipMainActorValue<Bool>(false)
        let started = expectation(description: "delay started")
        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            started.fulfill()
            await processor!.process(delay: delay, triggerDate: now)
            finished.set(true)
            ended.fulfill()
        }

        await self.fulfillment(of: [started])

        XCTAssertFalse(finished.value)

        self.analytics.setScreen("screen1")
        self.analytics.setRegions(Set(["region1"]))
        self.analytics.setRegions(Set(["region1"]))
        self.stateTracker.currentState = .active

        await self.fulfillment(of: [ended])
        XCTAssertTrue(finished.value)

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [100.0])
    }

    @MainActor
    func testTaskSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            await processor!.process(delay: delay, triggerDate: now)
            ended.fulfill()
        }

        await self.fulfillment(of: [ended])

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [100.0])
    }

    @MainActor
    func testRemainingSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            await processor!.process(delay: delay, triggerDate: now - 50.0)
            ended.fulfill()
        }

        await self.fulfillment(of: [ended])

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [50.0])
    }

    @MainActor
    func testSkipSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            await processor!.process(delay: delay, triggerDate: now - 100.0)
            ended.fulfill()
        }

        await self.fulfillment(of: [ended])

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [])
    }

    @MainActor
    func testEmptyDelay() async throws {
        let delay = AutomationDelay()

        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            await processor!.process(delay: delay, triggerDate: now - 100.0)
            ended.fulfill()
        }

        await self.fulfillment(of: [ended])

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [])

        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))
    }

    @MainActor
    func testNilDelay() async throws {
        let ended = expectation(description: "delay processed")

        let now = date.now
        Task { @MainActor [processor] in
            await processor!.process(delay: nil, triggerDate: now - 100.0)
            ended.fulfill()
        }

        await self.fulfillment(of: [ended])

        let sleeps = self.taskSleeper.sleeps
        XCTAssertEqual(sleeps, [])

        XCTAssertTrue(self.processor.areConditionsMet(delay: nil))
    }


    @MainActor
    func testScreenConditions() async throws {
        let delay = AutomationDelay(
            screens: ["screen1", "screen2"]
        )

        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))

        self.analytics.setScreen("screen1")
        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))

        self.analytics.setScreen("screen3")
        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))
    }

    @MainActor
    func testRegionCondition() async throws {
        let delay = AutomationDelay(
            regionID: "foo"
        )

        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))

        self.analytics.setRegions(Set(["foo", "baz"]))
        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))

        self.analytics.setRegions(Set(["bar", "baz"]))
        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))
    }


    @MainActor
    func testForegroundAppState() async throws {
        let delay = AutomationDelay(
            appState: .foreground
        )

        self.stateTracker.currentState = .background
        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .inactive
        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .active
        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))
    }

    @MainActor
    func testBackgroundAppState() async throws {
        let delay = AutomationDelay(
            appState: .background
        )

        self.stateTracker.currentState = .background
        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .inactive
        XCTAssertTrue(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .active
        XCTAssertFalse(self.processor.areConditionsMet(delay: delay))
    }


}
