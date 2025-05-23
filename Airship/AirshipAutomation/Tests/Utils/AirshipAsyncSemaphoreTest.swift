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
    func testSequentialPermitWithOnePermit() async throws {
        let semaphore = AirshipAsyncSemaphore(value: 1)
        let order: AirshipActorValue<[Int]> = AirshipActorValue([])

        async let first: () = semaphore.withPermit {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
            await order.update { value in
                value.append(1)
            }
        }

        async let second: () = semaphore.withPermit {
            await order.update { value in
                value.append(2)
            }
        }


        async let third: () = semaphore.withPermit {
            await order.update { value in
                value.append(3)
            }
        }

        _ = try await (first, second, third)

        await #expect(order.value == [1, 2, 3])
    }

    @Test
    func testSequentialPermitWith() async throws {
        let semaphore = AirshipAsyncSemaphore(value: 2)
        let order: AirshipActorValue<[Int]> = AirshipActorValue([])

        async let first: () = semaphore.withPermit {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
            await order.update { value in
                value.append(1)
            }
        }

        async let second: () = semaphore.withPermit {
            await order.update { value in
                value.append(2)
            }
        }
        _ = try await (first, second)

        await #expect(order.value == [2, 1])
    }
}
