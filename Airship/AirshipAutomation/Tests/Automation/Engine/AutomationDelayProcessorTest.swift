/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore


struct AutomationDelayProcessorTest {

    private let analytics: TestAnalytics = TestAnalytics()
    private let stateTracker: TestAppStateTracker = TestAppStateTracker()
    private let date: UATestDate = UATestDate()
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    private let processor: AutomationDelayProcessor
    private let executionWindowProcessor: TestExecutionWindowProcessor

    init() async throws {
        let executionWindowProcessor = TestExecutionWindowProcessor()
        self.executionWindowProcessor = executionWindowProcessor
        self.date.dateOverride = Date()
        self.processor = await AutomationDelayProcessor(
            analytics: analytics,
            appStateTracker: stateTracker,
            taskSleeper: taskSleeper,
            date: date,
            executionWindowProcessor: executionWindowProcessor
        )
    }

    @MainActor
    @Test
    func testProcess() async throws {
        let executionWindow = try ExecutionWindow(
            include: [ .weekly(daysOfWeek: [1]) ]
        )
        let delay = AutomationDelay(
            seconds: 100.0,
            screens: ["screen1", "screen2"],
            regionID: "region1",
            appState: .foreground,
            executionWindow: executionWindow
        )

        self.analytics.setScreen("screen1")
        self.analytics.setRegions(Set(["region1"]))
        self.stateTracker.currentState = .active

        // Report the window as inactive on the first check so the processor
        // enters its condition-wait loop and processes the window once, then
        // active so the loop exits.
        let isActiveChecks = AirshipMainActorValue<Int>(0)
        self.executionWindowProcessor.onIsActive = { window in
            #expect(window == executionWindow)
            let checks = isActiveChecks.value
            isActiveChecks.set(checks + 1)
            return checks > 0
        }

        let finished = AirshipMainActorValue<Bool>(false)

        let now = date.now
        let task = Task { @MainActor [processor] in
            await processor.process(delay: delay, triggerDate: now)
            finished.set(true)
        }

        #expect(!(finished.value))

        await task.value
        #expect(finished.value)

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [100.0])
        let processed = await self.executionWindowProcessor.getProcessed()
        #expect(processed == [executionWindow])
    }

    @MainActor
    @Test
    func testPreprocess() async throws {
        let executionWindow = try ExecutionWindow(
            include: [ .weekly(daysOfWeek: [1]) ]
        )

        let delay = AutomationDelay(
            seconds: 100.0,
            screens: ["screen1", "screen2"],
            regionID: "region1",
            appState: .foreground,
            executionWindow: executionWindow
        )

        let finished = AirshipMainActorValue<Bool>(false)

        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                try! await processor.preprocess(delay: delay, triggerDate: now)
                finished.set(true)
                ended()
            }
            await task.value
        }
        #expect(finished.value)

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [70.0])

        let processed = await self.executionWindowProcessor.getProcessed()
        #expect(processed == [executionWindow])
    }

    @MainActor
    @Test
    func testTaskSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                await processor.process(delay: delay, triggerDate: now)
                ended()
            }
            await task.value
        }

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [100.0])
    }

    @MainActor
    @Test
    func testRemainingSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                await processor.process(delay: delay, triggerDate: now - 50.0)
                ended()
            }
            await task.value
        }

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [50.0])
    }

    @MainActor
    @Test
    func testSkipSleep() async throws {
        let delay = AutomationDelay(
            seconds: 100.0
        )

        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                await processor.process(delay: delay, triggerDate: now - 100.0)
                ended()
            }
            await task.value
        }

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [])
    }

    @MainActor
    @Test
    func testEmptyDelay() async throws {
        let delay = AutomationDelay()

        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                await processor.process(delay: delay, triggerDate: now - 100.0)
                ended()
            }
            await task.value
        }

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [])

        #expect(self.processor.areConditionsMet(delay: delay))
    }

    @MainActor
    @Test
    func testNilDelay() async throws {
        let now = date.now
        await confirmation("delay processed") { ended in
            let task = Task { @MainActor [processor] in
                await processor.process(delay: nil, triggerDate: now - 100.0)
                ended()
            }
            await task.value
        }

        let sleeps = self.taskSleeper.sleeps
        #expect(sleeps == [])

        #expect(self.processor.areConditionsMet(delay: nil))
    }


    @MainActor
    @Test
    func testScreenConditions() async throws {
        let delay = AutomationDelay(
            screens: ["screen1", "screen2"]
        )

        #expect(!(self.processor.areConditionsMet(delay: delay)))

        self.analytics.setScreen("screen1")
        #expect(self.processor.areConditionsMet(delay: delay))

        self.analytics.setScreen("screen3")
        #expect(!(self.processor.areConditionsMet(delay: delay)))
    }

    @MainActor
    @Test
    func testRegionCondition() async throws {
        let delay = AutomationDelay(
            regionID: "foo"
        )

        #expect(!(self.processor.areConditionsMet(delay: delay)))

        self.analytics.setRegions(Set(["foo", "baz"]))
        #expect(self.processor.areConditionsMet(delay: delay))

        self.analytics.setRegions(Set(["bar", "baz"]))
        #expect(!(self.processor.areConditionsMet(delay: delay)))
    }


    @MainActor
    @Test
    func testForegroundAppState() async throws {
        let delay = AutomationDelay(
            appState: .foreground
        )

        self.stateTracker.currentState = .background
        #expect(!(self.processor.areConditionsMet(delay: delay)))

        self.stateTracker.currentState = .inactive
        #expect(!(self.processor.areConditionsMet(delay: delay)))

        self.stateTracker.currentState = .active
        #expect(self.processor.areConditionsMet(delay: delay))
    }

    @MainActor
    @Test
    func testBackgroundAppState() async throws {
        let delay = AutomationDelay(
            appState: .background
        )

        self.stateTracker.currentState = .background
        #expect(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .inactive
        #expect(self.processor.areConditionsMet(delay: delay))

        self.stateTracker.currentState = .active
        #expect(!(self.processor.areConditionsMet(delay: delay)))
    }

    @MainActor
    @Test
    func testExecutionWindow() async throws {
        let executionWindow = try ExecutionWindow(
            include: [ .weekly(daysOfWeek: [1]) ]
        )

        let delay = AutomationDelay(
            executionWindow: executionWindow
        )

        self.executionWindowProcessor.onIsActive = { _ in
            return false
        }
        #expect(!(self.processor.areConditionsMet(delay: delay)))

        self.executionWindowProcessor.onIsActive = { _ in
            return true
        }
        #expect(self.processor.areConditionsMet(delay: delay))
    }
}


fileprivate actor TestExecutionWindowProcessor: ExecutionWindowProcessorProtocol {

    private var processed: [ExecutionWindow] = []

    @MainActor
    var onIsActive: ((ExecutionWindow) -> Bool)?

    func process(window: ExecutionWindow) async throws {
        processed.append(window)
    }

    func getProcessed() -> [ExecutionWindow] {
        return processed
    }

    @MainActor
    func isActive(window: ExecutionWindow) -> Bool {
        return onIsActive?(window) ?? false
    }
}
