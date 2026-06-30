/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
@Suite
struct EventSchedulerTest {

    private let date = UATestDate()
    private let workManager = TestWorkManager()
    private let appStateTracker = TestAppStateTracker()
    private var eventScheduler: EventUploadScheduler!
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    init() {
        self.eventScheduler = EventUploadScheduler(
            appStateTracker: appStateTracker,
            workManager: workManager,
            date: date,
            taskSleeper: taskSleeper
        )
    }

    @Test
    @MainActor
    func testScheduleNormalPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        #expect(1 == self.workManager.workRequests.count)
        #expect(15.0 == self.workManager.workRequests[0].initialDelay)
    }

    @Test
    @MainActor
    func testScheduleHighPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .high,
            minBatchInterval: 60.0
        )

        #expect(1 == self.workManager.workRequests.count)
        #expect(0 == self.workManager.workRequests[0].initialDelay)
    }

    @Test
    @MainActor
    func testScheduleNormalPriorityBackground() async throws  {
        self.appStateTracker.currentState = .background
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        #expect(1 == self.workManager.workRequests.count)
        #expect(0 == self.workManager.workRequests[0].initialDelay)
    }

    @Test
    @MainActor
    func testAlreadyScheduled() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        #expect(1 == self.workManager.workRequests.count)
        #expect(15.0 == self.workManager.workRequests[0].initialDelay)
    }

    @Test
    @MainActor
    func testScheduleEarlier() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        await self.eventScheduler.scheduleUpload(
            eventPriority: .high,
            minBatchInterval: 60.0
        )

        #expect(2 == self.workManager.workRequests.count)
        #expect(15.0 == self.workManager.workRequests[0].initialDelay)
        #expect(0 == self.workManager.workRequests[1].initialDelay)
    }

    @Test
    @MainActor
    func testBatchInterval() async throws {
        self.date.dateOverride = Date()
        let request = AirshipWorkRequest(workID: "neat")
        let _ = try await self.workManager.workers[0].workHandler(request)

        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        #expect(1 == self.workManager.workRequests.count)
        #expect(60.0 == self.workManager.workRequests[0].initialDelay)
    }

    @Test
    @MainActor
    func testSmallerBatchInterval() async throws {
        self.date.dateOverride = Date()
        let request = AirshipWorkRequest(workID: "neat")
        let _ = try await self.workManager.workers[0].workHandler(request)

        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 90.0
        )

        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 30.0
        )

        #expect(2 == self.workManager.workRequests.count)
        #expect(60.0 == self.workManager.workRequests[0].initialDelay)
        #expect(30.0 == self.workManager.workRequests[1].initialDelay)
    }

    @Test
    func testWorkHandlerNotSet() async throws {
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        #expect(AirshipWorkResult.success == result)
    }

    @Test
    func testWorkBlockFailed() async throws {
        let called = AirshipAtomicValue<Bool>(false)
        await self.eventScheduler.setWorkBlock {
            called.value = true
            return .failure
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        #expect(AirshipWorkResult.failure == result)
        #expect(called.value)
    }

    @Test
    func testWorkBlockSuccess() async throws {
        let called = AirshipAtomicValue<Bool>(false)
        await self.eventScheduler.setWorkBlock {
            called.value = true
            return .success
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        #expect(AirshipWorkResult.success == result)
        #expect(called.value)
    }

    @Test
    @MainActor
    func testBatchDelay() async throws {
        self.appStateTracker.currentState = .inactive
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        #expect(AirshipWorkResult.success == result)
        let sleeps = await self.taskSleeper.sleeps
        #expect([1.0] == sleeps)
    }

    @Test
    @MainActor
    func testActiveBatchDelay() async throws {
        self.appStateTracker.currentState = .active
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        #expect(AirshipWorkResult.success == result)

        let sleeps = await self.taskSleeper.sleeps
        #expect([5.0] == sleeps)
    }
}
