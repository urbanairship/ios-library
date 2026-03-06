/* Copyright Airship and Contributors */

import Testing
@testable import AirshipAutomation
@testable import AirshipCore

struct AirshipAsyncSemaphoreTest {

    @Test
    func testPermitAllowsExecution() async throws {
        let semaphore = AirshipAsyncSemaphore(value: 1)

        let result = try await semaphore.withPermit {
            return "success"
        }

        #expect(result == "success")
    }

    @Test
    func testMutualExclusionWithOnePermit() async throws {
        let semaphore = AirshipAsyncSemaphore(value: 1)
        let concurrent: AirshipActorValue<Int> = AirshipActorValue(0)
        let maxConcurrent: AirshipActorValue<Int> = AirshipActorValue(0)
        let completedCount: AirshipActorValue<Int> = AirshipActorValue(0)

        async let first: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        async let second: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        async let third: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        _ = try await (first, second, third)

        await #expect(maxConcurrent.value <= 1)
        await #expect(completedCount.value == 3)
    }

    @Test
    func testConcurrencyLimitWithTwoPermits() async throws {
        let semaphore = AirshipAsyncSemaphore(value: 2)
        let concurrent: AirshipActorValue<Int> = AirshipActorValue(0)
        let maxConcurrent: AirshipActorValue<Int> = AirshipActorValue(0)
        let completedCount: AirshipActorValue<Int> = AirshipActorValue(0)

        async let first: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        async let second: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        async let third: () = semaphore.withPermit {
            let current = await concurrent.getAndUpdate { $0 += 1 }
            await maxConcurrent.update { $0 = max($0, current) }
            try await Task.sleep(nanoseconds: 50_000_000)
            await concurrent.update { $0 -= 1 }
            await completedCount.update { $0 += 1 }
        }

        _ = try await (first, second, third)

        await #expect(maxConcurrent.value <= 2)
        await #expect(completedCount.value == 3)
    }
}
