/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipNotificationServiceExtension

@Suite("Airship Notification Mutation Provider")
struct AirshipNotificationMutationProviderTests {

    @Test
    func concurrentMapPreservesAuthoredOrderDespiteOutOfOrderCompletion() async throws {
        // Delays are reversed so the first element finishes last, forcing the
        // task group to yield results out of order if nothing corrects for it.
        let elements = Array(0..<5)
        let delaysNanoseconds: [UInt64] = [400_000_000, 300_000_000, 200_000_000, 100_000_000, 0]

        let results = await AirshipNotificationMutationProvider.concurrentMapPreservingOrder(elements) { index in
            try? await Task.sleep(nanoseconds: delaysNanoseconds[index])
            return index
        }

        #expect(results == [0, 1, 2, 3, 4])
    }

    @Test
    func concurrentMapKeepsFailuresInPlaceWithoutShiftingOrder() async throws {
        let elements = Array(0..<4)

        let results: [Int?] = await AirshipNotificationMutationProvider.concurrentMapPreservingOrder(elements) { index in
            // Odd-indexed "downloads" fail; even ones resolve immediately.
            index.isMultiple(of: 2) ? index : nil
        }

        #expect(results == [0, nil, 2, nil])
    }
}
