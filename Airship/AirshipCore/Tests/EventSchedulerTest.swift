/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class EventSchedulerTest: XCTestCase {

    private let date = UATestDate()
    private let workManager = TestWorkManager()
    private let appStateTracker = TestAppStateTracker()
    private var eventScheduler: EventUploadScheduler!
    private var lastDelay: TimeInterval?

    override func setUpWithError() throws {
        self.eventScheduler = EventUploadScheduler(
            appStateTracker: appStateTracker,
            workManager: workManager,
            date: date,
            delayer: { time in
                self.lastDelay = time
            }
        )
    }

    func testScheduleNormalPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(15.0, self.workManager.workRequests[0].initialDelay)
    }

    func testScheduleHighPriority() async throws  {
        self.appStateTracker.currentState = .active
        await self.eventScheduler.scheduleUpload(
            eventPriority: .high,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(0, self.workManager.workRequests[0].initialDelay)
    }

    func testScheduleNormalPriorityBackground() async throws  {
        self.appStateTracker.currentState = .background
        await self.eventScheduler.scheduleUpload(
            eventPriority: .normal,
            minBatchInterval: 60.0
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        XCTAssertEqual(0, self.workManager.workRequests[0].initialDelay)
    }

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
        var called = false
        await self.eventScheduler.setWorkBlock {
            called = true
            return .failure
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.failure, result)
        XCTAssertTrue(called)
    }

    func testWorkBlockSuccess() async throws {
        var called = false
        await self.eventScheduler.setWorkBlock {
            called = true
            return .success
        }

        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertTrue(called)
    }

    func testBatchDelay() async throws {
        self.appStateTracker.currentState = .inactive
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertEqual(1.0, self.lastDelay)
    }

    func testActiveBatchDelay() async throws {
        self.appStateTracker.currentState = .active
        let request = AirshipWorkRequest(workID: "neat")
        let result = try await self.workManager.workers[0].workHandler(request)
        XCTAssertEqual(AirshipWorkResult.success, result)
        XCTAssertEqual(5.0, self.lastDelay)
    }
}
