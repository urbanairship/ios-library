/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

struct AirshipCoalescingCacheTest {

    private let date = UATestDate(offset: 0, dateOverride: Date())

    // A long idle TTL keeps the background clear timer (real sleeper) from firing
    // during a test; expiry is exercised deterministically by advancing `date`.
    private func makeCache(
        idleTTL: TimeInterval = 1000,
        isValid: @escaping @Sendable (Int) async -> Bool = { _ in true },
        load: @escaping @Sendable () async -> Int
    ) -> AirshipCoalescingCache<Int> {
        return AirshipCoalescingCache(
            idleTTL: idleTTL,
            date: date,
            isValid: isValid,
            load: load
        )
    }

    @Test
    func cachesValueAcrossCalls() async {
        let counter = LoadCounter()
        let cache = makeCache(load: { await counter.next() })

        let first = await cache.value()
        let second = await cache.value()

        #expect(first == 1)
        #expect(second == 1)
        let loads = await counter.count
        #expect(loads == 1)
    }

    @Test
    func reloadsWhenNotValid() async {
        let counter = LoadCounter()
        let cache = makeCache(isValid: { _ in false }, load: { await counter.next() })

        let first = await cache.value()
        let second = await cache.value()

        #expect(first == 1)
        #expect(second == 2)
        let loads = await counter.count
        #expect(loads == 2)
    }

    @Test
    func reloadsWhenExpired() async {
        let counter = LoadCounter()
        let cache = makeCache(idleTTL: 100, load: { await counter.next() })

        _ = await cache.value()          // loads; expires at +100
        date.offset += 101               // move past the idle TTL
        let reloaded = await cache.value()

        #expect(reloaded == 2)
        let loads = await counter.count
        #expect(loads == 2)
    }

    @Test
    func concurrentCallersShareOneLoad() async {
        let counter = LoadCounter()
        let gate = Gate()
        let cache = makeCache(load: {
            await gate.wait()
            return await counter.next()
        })

        async let results: [Int] = withTaskGroup(of: Int.self) { group in
            for _ in 0..<25 {
                group.addTask { await cache.value() }
            }
            var out: [Int] = []
            for await value in group {
                out.append(value)
            }
            return out
        }

        // Once a single load is in flight, release it: every caller shares it.
        await gate.waitUntilWaiting()
        await gate.open()

        let all = await results
        #expect(all == Array(repeating: 1, count: 25))
        let loads = await counter.count
        #expect(loads == 1)
    }
}

private actor LoadCounter {
    private(set) var count = 0
    func next() -> Int {
        count += 1
        return count
    }
}

/// Blocks `wait()` until `open()` is called; `waitUntilWaiting()` resolves once a
/// caller is parked in `wait()`. Used to hold a load in flight during a test.
private actor Gate {
    private var waiter: CheckedContinuation<Void, Never>?
    private var isWaiting = false
    private var waitingObservers: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        isWaiting = true
        waitingObservers.forEach { $0.resume() }
        waitingObservers.removeAll()
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        waiter?.resume()
        waiter = nil
    }

    func waitUntilWaiting() async {
        if isWaiting { return }
        await withCheckedContinuation { waitingObservers.append($0) }
    }
}
