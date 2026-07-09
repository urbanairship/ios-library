/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipAutomation
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
        try await verifyConcurrencyLimit(permits: 1, taskCount: 3)
    }

    @Test
    func testConcurrencyLimitWithTwoPermits() async throws {
        try await verifyConcurrencyLimit(permits: 2, taskCount: 3)
    }

    /// Verifies exactly `permits` tasks run concurrently, no more.
    private func verifyConcurrencyLimit(permits: Int, taskCount: Int) async throws {
        let semaphore = AirshipAsyncSemaphore(value: permits)
        let gate = TestGate()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<taskCount {
                group.addTask {
                    try await semaphore.withPermit {
                        await gate.arrive()
                    }
                }
            }

            // All permits should be taken now; the rest are blocked.
            await gate.waitForArrivals(permits)
            #expect(await gate.inside == permits)
            #expect(await gate.arrivedCount == permits)

            await gate.open()
            try await group.waitForAll()
        }

        #expect(await gate.arrivedCount == taskCount)
    }
}
