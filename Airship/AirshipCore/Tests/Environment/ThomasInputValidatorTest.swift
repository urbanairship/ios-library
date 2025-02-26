/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

struct ThomasInputValidatorTest {
    @Test("Test just true validation")
    @MainActor
    func testJustTrue() async throws {
        let validator = ThomasInputValidator.just(true)
        #expect(validator.result == .valid)
        #expect(await validator.waitResult() == .valid)
    }

    @Test("Test just false validation")
    @MainActor
    func testJustFalse() async throws {
        let validator = ThomasInputValidator.just(false)
        #expect(validator.result == .invalid)
        #expect(await validator.waitResult() == .invalid)
    }

    @Test("Test async validation delay")
    @MainActor
    func testAsyncValidationDelay() async throws {
        let taskSleeper = TestTaskSleeper()
        await taskSleeper.pause()

        let validator = ThomasInputValidator.async(
            earlyValidation: .delay(200.0),
            taskSleeper: taskSleeper
        ) {
            true
        }

        var sleeps = await taskSleeper.sleepUpdates.makeAsyncIterator()
        #expect(await sleeps.next() == [200])
        #expect(validator.result == nil)

        await taskSleeper.resume()
        _ = await validator.waitResult()
        #expect(validator.result != nil)
    }

    @Test("Test async validation when valid")
    @MainActor
    func testAsyncValidationValid() async throws {
        let taskSleeper = TestTaskSleeper()

        let validator = ThomasInputValidator.async(taskSleeper: taskSleeper) {
            true
        }
        #expect(await validator.waitResult() == .valid)
        #expect(validator.result == .valid)
    }

    @Test("Test async validation invalid")
    @MainActor
    func testAsyncValidationInvalid() async throws {
        let taskSleeper = TestTaskSleeper()

        let validator = ThomasInputValidator.async(taskSleeper: taskSleeper) {
            false
        }
        #expect(await validator.waitResult() == .invalid)
        #expect(validator.result == .invalid)
    }

    @Test("Test async validation error")
    @MainActor
    func testAsyncValidationError() async throws {
        let taskSleeper = TestTaskSleeper()
        let date = UATestDate(offset: 0, dateOverride: Date())

        await confirmation(expectedCount: 8) { confirmiation in
            let validator = ThomasInputValidator.async(
                earlyValidation: .never,
                date: date,
                taskSleeper: taskSleeper
            ) {
                confirmiation.confirm()
                throw AirshipErrors.error("invalid")
            }
            #expect(await validator.waitResult() == .error)
            #expect(validator.result == .error)

            #expect(await taskSleeper.sleeps.isEmpty)
            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0])

            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0])

            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0, 12.0])

            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0, 12.0, 15.0])

            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0, 12.0, 15.0, 15.0])

            date.offset += 10.0
            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0, 12.0, 15.0, 15.0, 5.0])

            #expect(await validator.waitResult() == .error)
            #expect(await taskSleeper.sleeps == [3.0, 6.0, 12.0, 15.0, 15.0, 5.0, 15.0])
        }
    }

}



