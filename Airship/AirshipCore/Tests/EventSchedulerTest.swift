/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class EventSchedulerTest: XCTestCase {

    private let date = UATestDate()
    private let workManager = TestWorkManager()
    private let appStateTracker = TestAppStateTracker()
    private var eventScheduler: EventUploadScheduler!
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()

    @MainActor
    override func setUp() async throws {
        self.eventScheduler = EventUploadScheduler(
            appStateTracker: appStateTracker,
            workManager: workManager,
            date: date,
            taskSleeper: taskSleeper
        )
    }

    @MainActor
    func testScheduleNormalPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(15.0, self.workManager.workRequests[0].initialDelay)
    }

    @MainActor
    func testScheduleHighPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .high,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(0, self.workManager.workRequests[0].initialDelay)
    }

    @MainActor
    func testScheduleNormalPriorityBackground() async throws  {
        self.appStateTracker.currentState = .background
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(0, self.workManager.workRequests[0].initialDelay)
    }

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

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(15.0, self.workManager.workRequests[0].initialDelay)
    }

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

        XCTAssertEqual(2, self.workManager.workRequests.count)
        XCTAssertEqual(15.0, self.workManager.workRequests[0].initialDelay)
        XCTAssertEqual(0, self.workManager.workRequests[1].initialDelay)
    }

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

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(60.0, self.workManager.workRequests[0].initialDelay)
    }

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

        XCTAssertEqual(2, self.workManager.workRequests.count)
        XCTAssertEqual(60.0, self.workManager.workRequests[0].initialDelay)
        XCTAssertEqual(30.0, self.workManager.workRequests[1].initialDelay)
    }

    func testWorkHandlerNotSet() async throws {
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
    }

    func testWorkBlockFailed() async throws {
        let called = AirshipAtomicValue<Bool>(false)
        await self.eventScheduler.setWorkBlock {
            called.value = true
            return .failure
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.failure, result)
        XCTAssertTrue(called.value)
    }

    func testWorkBlockSuccess() async throws {
        let called = AirshipAtomicValue<Bool>(false)
        await self.eventScheduler.setWorkBlock {
            called.value = true
            return .success
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertTrue(called.value)
    }

    @MainActor
    func testBatchDelay() async throws {
        self.appStateTracker.currentState = .inactive
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertEqual([1.0], self.taskSleeper.sleeps)
    }

    @MainActor
    func testActiveBatchDelay() async throws {
        self.appStateTracker.currentState = .active
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertEqual([5.0], self.taskSleeper.sleeps)
    }
}
