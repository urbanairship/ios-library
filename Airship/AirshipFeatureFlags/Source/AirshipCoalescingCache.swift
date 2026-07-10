/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipBasement
import AirshipCore


/// Actor that memoizes a single value with in-flight dedup so a burst of concurrent
/// lookups shares one load (request coalescing). Freshness is validated by the
/// caller-supplied `isValid`, and every lookup pushes the expiration out by
/// `idleTTL`. A single timer frees the value once the (repeatedly-extended)
/// expiration passes, so nothing is held resident outside of active use. All state
/// is actor-isolated, so no additional locking is needed.
actor AirshipCoalescingCache<Value: Sendable> {
    private let idleTTL: TimeInterval
    private let date: any AirshipDateProtocol
    private let taskSleeper: any AirshipTaskSleeper
    private let isValid: @Sendable (Value) async -> Bool
    private let load: @Sendable () async -> Value

    private var cachedValue: Value?
    private var expirationDate: Date?
    private var cacheRevision: UInt64 = 0

    private var loadTask: Task<Value, Never>?
    private var clearTask: Task<Void, any Error>?

    init(
        idleTTL: TimeInterval,
        date: any AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: any AirshipTaskSleeper = .shared,
        isValid: @escaping @Sendable (Value) async -> Bool,
        load: @escaping @Sendable () async -> Value
    ) {
        self.idleTTL = idleTTL
        self.date = date
        self.taskSleeper = taskSleeper
        self.isValid = isValid
        self.load = load
    }

    func value() async -> Value {
        if let cached = await cacheIfValid() {
            return cached
        }

        return await fetchValue()
    }

    private func fetchValue() async -> Value {
        let task = self.loadTask ?? Task { [load] in
            return await load()
        }

        self.loadTask = task

        let loaded = await task.value

        if self.loadTask == task {
            self.loadTask = nil
            self.cachedValue = loaded
            self.expirationDate = date.now.advanced(by: idleTTL)
            self.cacheRevision += 1
            scheduleClear()
        }

        return loaded
    }

    private func cacheIfValid() async -> Value? {
        guard let value = cachedValue, let expiration = expirationDate, date.now < expiration else {
            return nil
        }

        let startingRevision = self.cacheRevision
        let valid = await isValid(value)

        // If the cache was replaced while we awaited `isValid`, re-evaluate against
        // the new state instead of falling through to a redundant load — another
        // caller may have just committed a fresh value we can serve directly.
        guard self.cacheRevision == startingRevision else {
            return await cacheIfValid()
        }

        guard valid, let exp = self.expirationDate, date.now < exp else {
            return nil
        }

        self.expirationDate = date.now.advanced(by: idleTTL)
        return value
    }

    /// Runs a single timer that frees the value once its expiration passes. If a
    /// lookup extended the expiration while we slept, we re-sleep the remainder.
    /// `self` is captured weakly so the timer never keeps the actor alive.
    private func scheduleClear() {
        clearTask?.cancel()
        clearTask = Task { [weak self, taskSleeper] in
            while !Task.isCancelled, await self?.cachedValue != nil {
                guard let remaining = await self?.timeRemaining() else { return }
                try await taskSleeper.sleep(timeInterval: remaining)
                guard let self else { return }
                await self.clearIfExpired()
            }
        }
    }

    private func timeRemaining() -> TimeInterval {
        guard let expirationDate else { return 0 }
        return max(0, expirationDate.timeIntervalSince(date.now))
    }

    private func clearIfExpired() {
        if let expirationDate, date.now >= expirationDate {
            self.cachedValue = nil
            self.expirationDate = nil
            self.cacheRevision += 1
        }
    }
}
