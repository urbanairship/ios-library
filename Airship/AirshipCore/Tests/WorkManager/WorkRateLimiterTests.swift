import Foundation
import Testing
@testable import AirshipCore

@Suite("WorkRateLimiter")
struct WorkRateLimiterTests {

    // Helper to make a limiter with a test clock
    private func makeLimiter(start: TimeInterval = 1_000_000) -> (WorkRateLimiter, UATestDate) {
        let clock = UATestDate(dateOverride: Date(timeIntervalSince1970: start))
        let limiter = WorkRateLimiter(date: clock)
        return (limiter, clock)
    }

    @Test("First N hits succeed, (N+1)th blocks")
    func blocksAfterRate() async throws {
        let (limiter, _) = makeLimiter()
        try await limiter.set("foo", rate: 2, timeInterval: 10)

        #expect(await limiter.trackIfWithinLimit(["foo"]))
        #expect(await limiter.trackIfWithinLimit(["foo"]))
        #expect(!(await limiter.trackIfWithinLimit(["foo"])))  // third should block

        let wait = await limiter.nextAvailable(["foo"])
        #expect(wait > 0 && wait <= 10)
    }

    @Test("nextAvailable is the max across keys")
    func nextAvailableMaxAcrossKeys() async throws {
        let (limiter, clock) = makeLimiter()
        try await limiter.set("foo", rate: 2, timeInterval: 10)
        try await limiter.set("bar", rate: 1, timeInterval: 30)

        #expect(await limiter.trackIfWithinLimit(["foo"]))
        #expect(await limiter.trackIfWithinLimit(["foo"]))
        #expect(await limiter.trackIfWithinLimit(["bar"]))

        // Immediately, bar drives the wait (~30)
        let w0 = await limiter.nextAvailable(["foo", "bar"])
        #expect((29.999...30.001).contains(w0), "Expected ~30s, got \(w0)")

        // After 25s, max should be ~5s
        clock.advance(by: 25)
        let w1 = await limiter.nextAvailable(["foo", "bar"])
        #expect((4.999...5.001).contains(w1), "Expected ~5s, got \(w1)")
    }

    @Test("Pruning on read/write unblocks after window")
    func pruningUnblocks() async throws {
        let (limiter, clock) = makeLimiter()
        try await limiter.set("k", rate: 3, timeInterval: 5)

        #expect(await limiter.trackIfWithinLimit(["k"]))
        #expect(await limiter.trackIfWithinLimit(["k"]))
        #expect(await limiter.trackIfWithinLimit(["k"]))
        #expect(!(await limiter.trackIfWithinLimit(["k"]))) // blocked

        clock.advance(by: 6)
        #expect(await limiter.nextAvailable(["k"]) == 0)
        #expect(await limiter.trackIfWithinLimit(["k"]))
    }

    @Test("Negative waits clamp to 0")
    func clampNegativeToZero() async throws {
        let (limiter, clock) = makeLimiter()
        try await limiter.set("k", rate: 1, timeInterval: 10)

        #expect(await limiter.trackIfWithinLimit(["k"])) // consume 1
        clock.advance(by: 12)
        let w = await limiter.nextAvailable(["k"])
        #expect(w >= 0)
        #expect((0.0...0.001).contains(w))
    }

    @Test("Empty key set is a no-op success")
    func emptyKeys() async throws {
        let (limiter, _) = makeLimiter()
        #expect(await limiter.trackIfWithinLimit([]))
        #expect(await limiter.nextAvailable([]) == 0)
    }

    @Test("Unknown key behaves as within limit (no rule)")
    func unknownKeyNoRule() async throws {
        let (limiter, _) = makeLimiter()
        #expect(await limiter.trackIfWithinLimit(["unknown"]))
        #expect(await limiter.nextAvailable(["unknown"]) == 0)
    }

    @Test("Set<String> API does not double-count")
    func setKeysNoDoubleCount() async throws {
        let (limiter, _) = makeLimiter()
        try await limiter.set("foo", rate: 1, timeInterval: 10)
        #expect(await limiter.trackIfWithinLimit(Set(["foo"])))
        #expect(!(await limiter.trackIfWithinLimit(Set(["foo"]))))
    }

    @Test("All-or-nothing tracking across multiple keys")
    func allOrNothingAcrossKeys() async throws {
        let (limiter, _) = makeLimiter()
        try await limiter.set("a", rate: 1, timeInterval: 10)
        try await limiter.set("b", rate: 1, timeInterval: 10)

        #expect(await limiter.trackIfWithinLimit(["a"]))
        // Should fail for (a,b) because a is already at limit; and must not track either key
        #expect(!(await limiter.trackIfWithinLimit(["a","b"])))
        // b should still be free to use
        #expect(await limiter.trackIfWithinLimit(["b"]))
    }
}
