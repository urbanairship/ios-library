/* Copyright Airship and Contributors */

import Foundation

class RateLimiter {
    private struct RateLimitRule {
        let rate: Int
        let timeInterval: TimeInterval
    }

    enum Status {
        case overLimit(TimeInterval)
        case withinLimit(Int)
    }

    private var hits: [String: [Date]] = [:]
    private var rules: [String: RateLimitRule] = [:]
    private let date: AirshipDate

    init(date: AirshipDate = AirshipDate()) {
        self.date = date
    }

    func set(_ key: String, rate: Int, timeInterval: TimeInterval) throws {
        guard rate > 0, timeInterval > 0 else {
            throw AirshipErrors.error("Rate and time interval must be greater than 0")
        }
        
        self.rules[key] = RateLimitRule(rate: rate, timeInterval: timeInterval)
        self.hits[key] = []
    }

    func status(_ key: String) -> Status? {
        guard let rule = rules[key] else {
            AirshipLogger.debug("No rule for key \(key)")
            return nil
        }

        let date = date.now

        let filtered = filter(self.hits[key], rule: rule, date: date) ?? []
        let count = filtered.count

        if count >= rule.rate {
            let nextAvailable = rule.timeInterval - date.timeIntervalSince(filtered[count - rule.rate])
            return .overLimit(nextAvailable)
        } else {
            return .withinLimit(rule.rate - count)
        }
    }

    func track(_ key: String) {
        guard let rule = rules[key] else {
            AirshipLogger.debug("No rule for key \(key)")
            return
        }

        var keyHits = hits[key] ?? []
        keyHits.append(self.date.now)
        hits[key] = filter(keyHits, rule: rule, date: self.date.now)
    }

    private func filter(_ hits: [Date]?, rule: RateLimitRule, date: Date) -> [Date]? {
        guard let hits = hits else { return nil }
        return hits.filter { hit in
            return hit.addingTimeInterval(rule.timeInterval) > date
        }
    }
}


