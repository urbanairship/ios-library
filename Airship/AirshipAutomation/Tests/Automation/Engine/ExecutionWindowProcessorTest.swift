/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class ExecutionWindowProcessorTest: XCTestCase {

    fileprivate struct Evaluated : Equatable, Sendable{
        let window: ExecutionWindow
        let date: Date
    }

    private let date: UATestDate = UATestDate(dateOverride: Date())
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let notificationCenter: NotificationCenter = NotificationCenter()
    private var processor: ExecutionWindowProcessor!

    private let window: ExecutionWindow = try! ExecutionWindow(include: [.weekly(daysOfWeek: [1])])

    private var evaluatedWindows: AirshipAtomicValue<[Evaluated]> = .init([])
    private var onResult: AirshipAtomicValue<(() throws -> ExecutionWindowResult)?> = .init(nil)

    override func setUpWithError() throws {
        processor = ExecutionWindowProcessor(
            taskSleeper: taskSleeper,
            date: date,
            notificationCenter: notificationCenter,
            onEvaluate: { window, date in
                self.evaluatedWindows.update { t in
                    var mutated = t
                    mutated.append(Evaluated(window: window, date: date))
                    return mutated
                }
                return try self.onResult.value!()
            }
        )
    }

    @MainActor
    func testIsAvailable() throws {
        onResult.value = { throw AirshipErrors.error("Error!") }
        XCTAssertFalse(processor.isActive(window: window))

        onResult.value = { return .retry(100) }
        XCTAssertFalse(processor.isActive(window: window))

        onResult.value = { return .now }
        XCTAssertTrue(processor.isActive(window: window))

        let evaluated = Evaluated(window: window, date: date.now)
        XCTAssertEqual(evaluatedWindows.value, [evaluated, evaluated, evaluated])
    }

    func testProcessError() async throws {
        let setup = expectation(description: "setup")

        let task = Task {
            await self.fulfillment(of: [setup])
            await processor.process(window: window)
        }

        taskSleeper.onSleep = { _ in
            task.cancel()
        }

        onResult.value = {
            throw AirshipErrors.error("Error!")
        }
        setup.fulfill()

        await task.value

        XCTAssertEqual(taskSleeper.sleeps, [24.0 * 60 * 60])
        let evaluated = Evaluated(window: window, date: date.now)
        XCTAssertEqual(evaluatedWindows.value, [evaluated])
    }

    func testProcessRetry() async throws {
        let setup = expectation(description: "setup")

        let task = Task {
            await self.fulfillment(of: [setup])
            await processor.process(window: window)
        }

        taskSleeper.onSleep = { _ in
            task.cancel()
        }

        onResult.value = {
            .retry(100.0)
        }
        setup.fulfill()

        await task.value

        XCTAssertEqual(taskSleeper.sleeps, [100.0])
        let evaluated = Evaluated(window: window, date: date.now)
        XCTAssertEqual(evaluatedWindows.value, [evaluated])
    }

    func testLocaleChangeRechecks() async throws {
        let setup = expectation(description: "setup")

        let task = Task {
            await self.fulfillment(of: [setup])
            await processor.process(window: window)
        }

        taskSleeper.onSleep = { sleeps in
            if sleeps.count == 1 {
                // Actually sleep on the first one to avoid a busy loop
                try await Task.sleep(nanoseconds: 1000000)
            } else {
                task.cancel()
            }
        }

        onResult.value = {
            .retry(1000.0)
        }

        setup.fulfill()

        notificationCenter.post(name: .NSSystemTimeZoneDidChange, object: nil)

        await task.value

        XCTAssertEqual(taskSleeper.sleeps, [1000.0, 1000.0])
        let evaluated = Evaluated(window: window, date: date.now)
        XCTAssertEqual(evaluatedWindows.value, [evaluated, evaluated])
    }

}
