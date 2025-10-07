/* Copyright Airship and Contributors */

import Foundation

actor WorkRateLimiter {

    private struct RateLimiterState: Sendable {
        let rate: Int
        let timeInterval: TimeInterval
        var hits: [Date] = []

        mutating func prune(now: Date) {
            let cutoff = now.addingTimeInterval(-timeInterval)
            hits.removeAll { $0 <= cutoff }

            if hits.count > rate {
                hits.removeFirst(hits.count - rate)
            }
        }
    }

    enum Status: Sendable {
        case overLimit(TimeInterval)
        case withinLimit(Int)
    }

    private var limiters: [String: RateLimiterState] = [:]
    private let date: any AirshipDateProtocol

    init(date: any AirshipDateProtocol = AirshipDate()) {
        self.date = date
    }

    func set(_ key: String, rate: Int, timeInterval: TimeInterval) throws {
        guard rate > 0, timeInterval > 0 else {
            throw AirshipErrors.error("Rate and time interval must be greater than 0")
        }

        var newState = RateLimiterState(
            rate: rate,
            timeInterval: timeInterval,
            hits: []
        )
        // Reserve rate + 1 capacity. We prune after adding a value so it should only ever grow by 1 more than the rate.
        newState.hits.reserveCapacity(rate + 1)
        self.limiters[key] = newState
    }

    func nextAvailable(_ keys: Set<String>) -> TimeInterval {
        keys.reduce(0.0) { maxDelay, key in
            guard case let .overLimit(delay)? = status(key) else {
                return maxDelay
            }
            return max(maxDelay, delay)
        }
    }

    func trackIfWithinLimit(_ keys: Set<String>) -> Bool {
        guard !keys.isEmpty else {
            return true
        }

        // Check first
        for key in keys {
            if case .overLimit? = status(key) {
                return false
            }
        }

        let now = date.now
        keys.forEach { track($0, now: now) }
        return true
    }

    private func status(_ key: String) -> Status? {
        guard var limiter = self.limiters[key] else {
            AirshipLogger.debug("No rule for key \(key)")
            return nil
        }

        let now = date.now

        // Save the struct back with pruned hits
        limiter.prune(now: now)
        self.limiters[key] = limiter

        let count = limiter.hits.count
        guard count >= limiter.rate else {
            return .withinLimit(limiter.rate - count)
        }

        let oldestHitIndex = count - limiter.rate

        guard oldestHitIndex >= 0, oldestHitIndex < limiter.hits.count else {
            AirshipLogger.error("Rate limiter index check failed for key \(key). Count: \(count), Rate: \(limiter.rate)")
            return .overLimit(limiter.timeInterval)
        }

        let gate = limiter.hits[oldestHitIndex]
        let wait = limiter.timeInterval - now.timeIntervalSince(gate)
        return .overLimit(max(wait, 0))
    }

    private func track(_ key: String, now: Date) {
        guard var limiter = self.limiters[key] else {
            AirshipLogger.debug("No rule for key \(key)")
            return
        }

        // Append and then prune the state
        limiter.hits.append(now)
        limiter.prune(now: now)

        // Save the updated struct back
        self.limiters[key] = limiter
    }
}
