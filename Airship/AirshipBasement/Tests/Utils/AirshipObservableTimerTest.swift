/* Copyright Airship and Contributors */

import Foundation
import Testing
@_spi(AirshipInternal) @testable import AirshipBasement

// Fake sleeper: records each interval and returns immediately.
// waitForCount suspends until N sleeps have been recorded, yielding the
// main actor so the @MainActor timer task can make progress.
private actor TestSleeper: AirshipTaskSleeper {
    private(set) var sleeps: [TimeInterval] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        let count = sleeps.count
        waiters.removeAll { needed, cont in
            if count >= needed { cont.resume(); return true }
            return false
        }
    }

    func waitForCount(_ n: Int) async {
        if sleeps.count >= n { return }
        await withCheckedContinuation { cont in
            waiters.append((n, cont))
        }
    }
}

@MainActor
struct AirshipObservableTimerTest {

    // waitForCount resumes the moment a sleep is *recorded* (the start of the
    // sleep). The timer still needs one or more scheduling hops afterward to
    // wake, bump elapsedTime, and set isExpired — so poll with bounded yields
    // rather than relying on a single Task.yield().
    private func waitUntilExpired(_ timer: AirshipObservableTimer) async {
        var attempts = 0
        while !timer.isExpired, attempts < 100 {
            await Task.yield()
            attempts += 1
        }
    }

    // tick = 0.1, duration = 0.3 → 3 sleeps of 0.1
    @Test
    func expiresAfterDuration() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.3, taskSleeper: sleeper)
        timer.onAppear()
        await sleeper.waitForCount(3)
        await waitUntilExpired(timer)
        #expect(timer.isExpired)
        let sleeps = await sleeper.sleeps
        #expect(sleeps == [0.1, 0.1, 0.1])
    }

    // Last tick should be min(remaining, tick): duration=0.25, tick=0.1
    // sleeps: 0.1, 0.1, 0.05 (last tick clamped to remaining 0.05)
    @Test
    func lastTickClampedToRemaining() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.25, taskSleeper: sleeper)
        timer.onAppear()
        await sleeper.waitForCount(3)
        await waitUntilExpired(timer)
        #expect(timer.isExpired)
        let sleeps = await sleeper.sleeps
        #expect(sleeps == [0.1, 0.1, 0.05])
    }

    @Test
    func nilDurationNeverExpires() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: nil, taskSleeper: sleeper)
        timer.onAppear()
        // Timer with no duration should never tick at all
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(!timer.isExpired)
        let sleeps = await sleeper.sleeps
        #expect(sleeps.isEmpty)
        timer.onDisappear()
    }

    @Test
    func pausedTimerDoesNotAccumulateTime() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.2, taskSleeper: sleeper)
        timer.onAppear()
        timer.isPaused = true
        // Let it run a few paused ticks
        await sleeper.waitForCount(3)
        #expect(!timer.isExpired)
        timer.onDisappear()
    }

    @Test
    func resumeAfterPauseEventuallyExpires() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.2, taskSleeper: sleeper)
        timer.onAppear()
        timer.isPaused = true
        // Run a few paused ticks (these don't count toward duration)
        await sleeper.waitForCount(3)
        #expect(!timer.isExpired)
        timer.isPaused = false
        // Now 2 active ticks of 0.1 should expire it
        await sleeper.waitForCount(5)
        await waitUntilExpired(timer)
        #expect(timer.isExpired)
    }

    @Test
    func onDisappearStopsTimer() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.3, taskSleeper: sleeper)
        timer.onAppear()
        // Let one tick fire then stop
        await sleeper.waitForCount(1)
        timer.onDisappear()
        let countAfterStop = await sleeper.sleeps.count
        // No further sleeps should be recorded after a brief yield
        try await Task.sleep(nanoseconds: 20_000_000)
        let countAfterWait = await sleeper.sleeps.count
        #expect(!timer.isExpired)
        #expect(countAfterStop == countAfterWait)
    }

    @Test
    func onAppearAfterExpiryIsNoOp() async throws {
        let sleeper = TestSleeper()
        let timer = AirshipObservableTimer(duration: 0.1, taskSleeper: sleeper)
        timer.onAppear()
        await sleeper.waitForCount(1)
        await waitUntilExpired(timer)
        #expect(timer.isExpired)
        timer.onAppear()
        #expect(timer.isExpired)
    }
}
