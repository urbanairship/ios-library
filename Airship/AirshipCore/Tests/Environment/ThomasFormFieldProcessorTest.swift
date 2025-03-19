/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@MainActor
struct ThomasFormFieldProcessorTest {
    private let processor: DefaultThomasFormFieldProcessor
    private let taskSleeper = TestTaskSleeper()
    private let date = UATestDate(offset: 0, dateOverride: Date())

    init() {
        self.processor = DefaultThomasFormFieldProcessor(
            date: self.date,
            taskSleeper: self.taskSleeper
        )
    }

    @Test("Test early process delay")
    func testProcessingEarlyProcessDelay() async throws {
        await taskSleeper.pause()

        let request = processor.submit(processDelay: 200.0) {
            return .invalid
        }

        var sleeps = await taskSleeper.sleepUpdates.makeAsyncIterator()
        #expect(await sleeps.next() == [200])
        #expect(request.result == nil)

        await taskSleeper.resume()
        await request.process(retryErrors: false)
        #expect(request.result == .invalid)
    }

    @Test("Test negative early process delay should pass to task sleeper")
    func testProcessingEarlyProcessNatativeDelay() async throws {
        await taskSleeper.pause()

        let request = processor.submit(processDelay: -1.0) {
            return .invalid
        }

        var sleeps = await taskSleeper.sleepUpdates.makeAsyncIterator()
        #expect(await sleeps.next() == [-1.0])
        #expect(request.result == nil)

        await taskSleeper.resume()
        await request.process(retryErrors: false)
        #expect(request.result == .invalid)
    }

    @Test("Test invalid result does not retry")
    func testInvalidResultDoesNotRetry() async throws {
        await confirmation { confirmation in
            let request = processor.submit(processDelay: 1.0) {
                confirmation.confirm()
                return .invalid
            }
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            #expect(request.result == .invalid)
        }

        #expect(await taskSleeper.sleeps == [1.0])
    }

    @Test("Test valid result does not retry")
    func testValidResultDoesNotRetry() async throws {
        let result = ThomasFormFieldPendingResult.valid(.init(value: .score(100)))
        await confirmation { confirmation in
            let request = processor.submit(processDelay: 1.0) {
                confirmation.confirm()
                return result
            }
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            #expect(request.result == result)
        }

        #expect(await taskSleeper.sleeps == [1.0])
    }

    @Test("Test error result will retry")
    func testErrorRetries() async throws {
        await confirmation(expectedCount: 3) { confirmation in
            let request = processor.submit(processDelay: 1.0) {
                confirmation.confirm()
                return .error
            }
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            await request.process(retryErrors: true)
            #expect(request.result == .error)
        }
    }

    @Test("Test retry backoff")
    func testAsyncValidationError() async throws {
        await confirmation(expectedCount: 8) { confirmation in
            let request = processor.submit(processDelay: 1.0) {
                confirmation.confirm()
                return .error
            }

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0, 12.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0, 12.0, 15.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0, 12.0, 15.0, 15.0])

            date.offset += 10.0
            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0, 12.0, 15.0, 15.0, 5.0])

            await request.process(retryErrors: true)
            #expect(await taskSleeper.sleeps == [1.0, 3.0, 6.0, 12.0, 15.0, 15.0, 5.0, 15.0])
        }
    }

    @Test("Test updates")
    func testUpdates() async throws {
        var resultStream = AsyncStream<ThomasFormFieldPendingResult> { continuation in
            continuation.yield(.error)
            continuation.yield(.error)
            continuation.yield(.invalid)
        }.makeAsyncIterator()

        let request = processor.submit(processDelay: 1.0) {
            return await resultStream.next()!
        }

        var updates = request.resultUpdates { result in
            guard let result else {
                return "pending"
            }
            return if result == .error {
                "error"
            } else {
                "not an error"
            }
        }.makeAsyncIterator()

        #expect(await updates.next() == "pending")

        await request.process(retryErrors: true)
        #expect(await updates.next() == "error")

        await request.process(retryErrors: true)
        #expect(await updates.next() == "error")

        await request.process(retryErrors: true)
        #expect(await updates.next() == "not an error")
    }

}



