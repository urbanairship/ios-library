/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

@MainActor
struct ExecutionWindowProcessorTest {

    fileprivate struct Evaluated : Equatable, Sendable{
        let window: ExecutionWindow
        let date: Date
    }

    private let date: UATestDate = UATestDate(dateOverride: Date())
    private let taskSleeper: TestTaskSleeper = TestTaskSleeper()
    private let notificationCenter: NotificationCenter = NotificationCenter()
    private let processor: ExecutionWindowProcessor

    private let window: ExecutionWindow = try! ExecutionWindow(include: [.weekly(daysOfWeek: [1])])

    private var evaluatedWindows: AirshipAtomicValue<[Evaluated]> = .init([])
    private var onResult: AirshipAtomicValue<(@Sendable () throws -> ExecutionWindowResult)?> = .init(nil)

    init() {
        let evaluatedWindows = self.evaluatedWindows
        let onResult = self.onResult
        processor = ExecutionWindowProcessor(
            taskSleeper: taskSleeper,
            date: date,
            notificationCenter: notificationCenter,
            onEvaluate: { window, date in
                evaluatedWindows.update { $0.append(Evaluated(window: window, date: date)) }
                return try onResult.value!()
            }
        )
    }

    @Test
    func testIsAvailable() throws {
        onResult.set({ throw AirshipErrors.error("Error!") })
        #expect(!(processor.isActive(window: window)))

        onResult.set({ return .retry(100) })
        #expect(!(processor.isActive(window: window)))

        onResult.set({ return .now })
        #expect(processor.isActive(window: window))

        let evaluated = Evaluated(window: window, date: date.now)
        #expect(evaluatedWindows.value == [evaluated, evaluated, evaluated])
    }

    @Test
    func testProcessError() async throws {
        let task = Task {
            await processor.process(window: window)
        }

        taskSleeper.onSleep = { _ in
            task.cancel()
        }

        onResult.set({
            throw AirshipErrors.error("Error!")
        })

        await task.value

        #expect(taskSleeper.sleeps == [24.0 * 60 * 60])
        let evaluated = Evaluated(window: window, date: date.now)
        #expect(evaluatedWindows.value == [evaluated])
    }

    @Test
    func testProcessRetry() async throws {
        let task = Task {
            await processor.process(window: window)
        }

        taskSleeper.onSleep = { _ in
            task.cancel()
        }

        onResult.set({
            .retry(100.0)
        })

        await task.value

        #expect(taskSleeper.sleeps == [100.0])
        let evaluated = Evaluated(window: window, date: date.now)
        #expect(evaluatedWindows.value == [evaluated])
    }

    @Test
    func testLocaleChangeRechecks() async throws {
        let task = Task {
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

        onResult.set({
            .retry(1000.0)
        })

        notificationCenter.post(name: .NSSystemTimeZoneDidChange, object: nil)

        await task.value

        #expect(taskSleeper.sleeps == [1000.0, 1000.0])
        let evaluated = Evaluated(window: window, date: date.now)
        #expect(evaluatedWindows.value == [evaluated, evaluated])
    }

}
