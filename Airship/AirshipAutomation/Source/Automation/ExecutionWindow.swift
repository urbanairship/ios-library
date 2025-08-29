/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

public struct ExecutionWindow: Sendable, Equatable, Codable {

    let include: [Rule]?
    let exclude: [Rule]?


    init(include: [Rule]? = nil, exclude: [Rule]? = nil) throws {
        self.include = include
        self.exclude = exclude
        try self.validate()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.include = try container.decodeIfPresent([ExecutionWindow.Rule].self, forKey: .include)
        self.exclude = try container.decodeIfPresent([ExecutionWindow.Rule].self, forKey: .exclude)
        try self.validate()
    }

    fileprivate func validate() throws {
        try include?.forEach { try $0.validate() }
        try exclude?.forEach { try $0.validate() }
    }

    enum Rule: Sendable, Codable, Equatable {
        case daily(timeRange: TimeRange, timeZone: TimeZone? = nil)
        case weekly(daysOfWeek: [Int], timeRange: TimeRange? = nil,  timeZone: TimeZone? = nil)
        case monthly(months: [Int]? = nil, daysOfMonth: [Int]? = nil, timeRange: TimeRange? = nil, timeZone: TimeZone? = nil)

        enum CodingKeys: String, CodingKey {
            case type
            case timeRange = "time_range"
            case daysOfWeek = "days_of_week"
            case daysOfMonth = "days_of_month"
            case timeZone = "time_zone"
            case months = "months"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(RuleType.self, forKey: .type)
            switch(type) {
            case .daily:
                self = .daily(
                    timeRange: try container.decode(TimeRange.self, forKey: .timeRange),
                    timeZone: try container.decodeIfPresent(TimeZone.self, forKey: .timeZone)
                )
            case .weekly:
                self = .weekly(
                    daysOfWeek: try container.decode([Int].self, forKey: .daysOfWeek),
                    timeRange: try container.decodeIfPresent(TimeRange.self, forKey: .timeRange),
                    timeZone: try container.decodeIfPresent(TimeZone.self, forKey: .timeZone)
                )
            case .monthly:
                self = .monthly(
                    months: try container.decodeIfPresent([Int].self, forKey: .months),
                    daysOfMonth: try container.decodeIfPresent([Int].self, forKey: .daysOfMonth),
                    timeRange: try container.decodeIfPresent(TimeRange.self, forKey: .timeRange),
                    timeZone: try container.decodeIfPresent(TimeZone.self, forKey: .timeZone)
                )
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch(self) {
            case .daily(timeRange: let timeRange, timeZone: let timeZone):
                try container.encode(RuleType.daily, forKey: .type)
                try container.encode(timeRange, forKey: .timeRange)
                try container.encodeIfPresent(timeZone, forKey: .timeZone)
            case .weekly(daysOfWeek: let daysOfWeek, timeRange: let timeRange, timeZone: let timeZone):
                try container.encode(RuleType.weekly, forKey: .type)
                try container.encodeIfPresent(daysOfWeek, forKey: .daysOfWeek)
                try container.encodeIfPresent(timeRange, forKey: .timeRange)
                try container.encodeIfPresent(timeZone, forKey: .timeZone)
            case .monthly(months: let months, daysOfMonth: let daysOfMonth, timeRange: let timeRange, timeZone: let timeZone):
                try container.encode(RuleType.monthly, forKey: .type)
                try container.encodeIfPresent(months, forKey: .months)
                try container.encodeIfPresent(daysOfMonth, forKey: .daysOfMonth)
                try container.encodeIfPresent(timeRange, forKey: .timeRange)
                try container.encodeIfPresent(timeZone, forKey: .timeZone)
            }
        }


        fileprivate func validate() throws {
            switch(self) {
            case .daily(let timeRange, _):
                try timeRange.validate()
            case .weekly(daysOfWeek: let daysOfWeek, timeRange: let timeRange, timeZone: _):
                guard !daysOfWeek.isEmpty else {
                    throw AirshipErrors.error("Invalid daysOfWeek: \(daysOfWeek), must contain at least 1 day of week")
                }
                try daysOfWeek.forEach { dayOfWeek in
                    guard dayOfWeek >= 1 && dayOfWeek <= 7 else {
                        throw AirshipErrors.error("Invalid daysOfWeek: \(daysOfWeek), all values must be [1-7]")
                    }
                }
                try timeRange?.validate()
            case .monthly(months: let months, daysOfMonth: let daysOfMonth, timeRange: let timeRange, timeZone: _):
                guard months?.isEmpty == false || daysOfMonth?.isEmpty == false else {
                    throw AirshipErrors.error("monthly rule must define either months or days of month")
                }
                try months?.forEach { month in
                    guard month >= 1 && month <= 12 else {
                        throw AirshipErrors.error("Invalid month: \(months ?? []), all values must be [1-12]")
                    }
                }

                try daysOfMonth?.forEach { dayOfMonth in
                    guard dayOfMonth >= 1 && dayOfMonth <= 31 else {
                        throw AirshipErrors.error("Invalid days of month: \(daysOfMonth ?? []), all values must be [1-31]")
                    }
                }

                try timeRange?.validate()
            }
        }
    }


    enum TimeZone: Sendable, Equatable, Codable{
        case utc
        case identifiers([String], secondsFromUTC: Int? = nil, onFailure: TimeZoneFailureMode = .error)
        case local

        enum CodingKeys: String, CodingKey {
            case type
            case identifiers
            case secondsFromUTC = "fallback_seconds_from_utc"
            case onFailure = "on_failure"

        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(TimeZoneType.self, forKey: .type)
            switch(type) {
            case .local:
                self = .local
            case .utc:
                self = .utc
            case .identifiers:
                self = .identifiers(
                    try container.decode([String].self, forKey: .identifiers),
                    secondsFromUTC: try container.decodeIfPresent(Int.self, forKey: .secondsFromUTC),
                    onFailure: try container.decode(TimeZoneFailureMode.self, forKey: .onFailure)
                )
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch(self) {
            case .local:
                try container.encode(TimeZoneType.local, forKey: .type)
            case .utc:
                try container.encode(TimeZoneType.utc, forKey: .type)
            case .identifiers(let identifiers, let secondsFromUTC, let failureMode):
                try container.encode(TimeZoneType.identifiers, forKey: .type)
                try container.encode(identifiers, forKey: .identifiers)
                try container.encodeIfPresent(secondsFromUTC, forKey: .secondsFromUTC)
                try container.encode(failureMode, forKey: .onFailure)
            }
        }
    }

    enum TimeZoneFailureMode: String, Sendable, Equatable, Codable {
        case error = "error"
        case skip = "skip"
    }

    struct TimeRange: Hashable, Equatable, Sendable, Codable {
        var startHour: Int
        var startMinute: Int
        var endHour: Int
        var endMinute: Int

        enum CodingKeys: String, CodingKey {
            case startHour = "start_hour"
            case startMinute = "start_minute"
            case endHour = "end_hour"
            case endMinute = "end_minute"
        }

        init(startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) {
            self.startHour = startHour
            self.startMinute = startMinute
            self.endHour = endHour
            self.endMinute = endMinute
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.startHour = try container.decode(Int.self, forKey: .startHour)
            self.startMinute = try container.decode(Int.self, forKey: .startMinute)
            self.endHour = try container.decode(Int.self, forKey: .endHour)
            self.endMinute = try container.decode(Int.self, forKey: .endMinute)
        }

        fileprivate func validate() throws {
            guard startHour >= 0 && startHour <= 23 else {
                throw AirshipErrors.error("Invalid startHour: \(startHour), must be [0-23]")
            }

            guard startMinute >= 0 && startMinute <= 59 else {
                throw AirshipErrors.error("Invalid startMinute: \(startMinute), must be [0-59]")
            }

            guard endHour >= 0 && endHour <= 23 else {
                throw AirshipErrors.error("Invalid endHour: \(endHour), must be [0-23]")
            }

            guard endMinute >= 0 && endMinute <= 59 else {
                throw AirshipErrors.error("Invalid endMinute: \(endMinute), must be [0-59]")
            }
        }
    }

    private enum RuleType: String, Sendable, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
    }

    private enum TimeZoneType: String, Sendable, Codable {
        case utc = "utc"
        case local = "local"
        case identifiers = "identifiers"
    }
}

enum ExecutionWindowResult: Equatable {
    case now
    case retry(TimeInterval)
}

extension ExecutionWindow {
    func nextAvailability(date: Date, currentTimeZone: Foundation.TimeZone? = nil) throws -> ExecutionWindowResult {
        let timeZone = currentTimeZone ?? Foundation.TimeZone.current

        let excluded = try self.exclude?.compactMap {
            try $0.resolve(date: date, currentTimeZone: timeZone)
        }.filter {
            $0.isWithin(date: date)
        }.sorted { l, r in
            /// Sort them with the longest exclude first
            l.end > r.end
        }.first

        if let excluded {
            return .retry(max(1.seconds, excluded.end.timeIntervalSince(date)))
        }

        let nextInclude = try include?.compactMap {
            try $0.resolve(date: date, currentTimeZone: timeZone)
        }.sorted { l, r in
            // Sort with the next window first
            l.start < r.start
        }.first

        guard let nextInclude, !nextInclude.isWithin(date: date) else {
            return .now
        }

        return .retry(max(1.seconds, nextInclude.start.timeIntervalSince(date)))
    }

}

fileprivate extension Int {
    var hours: TimeInterval {
        TimeInterval(self) * 60 * 60
    }

    var minutes: TimeInterval {
        TimeInterval(self) * 60
    }

    var seconds: TimeInterval {
        TimeInterval(self)
    }
}

fileprivate extension ExecutionWindow.TimeRange {
    var start: TimeInterval {
        return startHour.hours + startMinute.minutes
    }

    var end: TimeInterval {
        return endHour.hours + endMinute.minutes
    }
}

fileprivate extension ExecutionWindow.TimeZone {

    enum TimeZoneResult {
        case resolved(Foundation.TimeZone)
        case error(ExecutionWindow.TimeZoneFailureMode)
    }

    func resolve(currentTimeZone: TimeZone) -> TimeZoneResult {
        switch(self) {
        case .utc:
            if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
                return .resolved(.gmt)
            } else {
                guard let utc = TimeZone(secondsFromGMT: 0) else  {
                    return .error(.error)
                }
                return .resolved(utc)
            }

        case .local:
            return .resolved(currentTimeZone)

        case .identifiers(let identifiers, let secondsFromUTC, let failureMode):
            for identifier in identifiers {
                if let timeZone = TimeZone(identifier: identifier) {
                    return .resolved(timeZone)
                }
            }

            if let secondsFromUTC, let timeZone = TimeZone(secondsFromGMT: secondsFromUTC) {
                return .resolved(timeZone)
            }

            AirshipLogger.error("Failed to resolve time zone identifiers: \(identifiers)")
            return .error(failureMode)
        }
    }
}

fileprivate extension ExecutionWindow.Rule {

    private func calendar(timeZone: ExecutionWindow.TimeZone?, currentTimeZone: Foundation.TimeZone) throws -> AirshipCalendar? {
        guard let timeZone else {
            return AirshipCalendar(timeZone: currentTimeZone)
        }

        switch (timeZone.resolve(currentTimeZone: currentTimeZone)) {
        case .resolved(let resolved):
            return AirshipCalendar(timeZone: resolved)
        case .error(let failureMode):
            switch(failureMode) {
            case .skip:
                return nil
            case .error:
                throw AirshipErrors.error("Unable to resolve time zone: \(timeZone)")
            }
        }
    }

    func resolve(date: Date, currentTimeZone: Foundation.TimeZone) throws -> DateInterval? {
        switch (self) {
        case .daily(timeRange: let timeRange, timeZone: let timeZone):
            guard let calendar = try calendar(
                timeZone: timeZone,
                currentTimeZone: currentTimeZone
            ) else {
                return nil
            }
            return calendar.dateInterval(date: date, timeRange: timeRange)

        case .weekly(daysOfWeek: let daysOfWeek, timeRange: let timeRange, timeZone: let timeZone):
            guard let calendar = try calendar(
                timeZone: timeZone,
                currentTimeZone: currentTimeZone
            ) else {
                return nil
            }

            guard let timeRange else {
                let nextDate = calendar.nextDate(date: date, weekdays: daysOfWeek)
                return calendar.remainingDay(date: nextDate)
            }

            var nextDate = calendar.nextDate(date: date, weekdays: daysOfWeek)

            while true {
                let timeInterval = calendar.dateInterval(date: nextDate, timeRange: timeRange)
                let remainingDay = calendar.remainingDay(date: nextDate)

                guard let result = timeInterval.intersection(with: remainingDay) else {
                    nextDate = calendar.nextDate(
                        date: calendar.startOfDay(date: date, dayOffset: 1),
                        weekdays: daysOfWeek
                    )
                    continue
                }

                return result
            }

        case .monthly(months: let months, daysOfMonth: let daysOfMonth, timeRange: let timeRange, timeZone: let timeZone):
            guard let calendar = try calendar(
                timeZone: timeZone,
                currentTimeZone: currentTimeZone
            ) else {
                return nil
            }

            guard let timeRange else {
                let nextDate = calendar.nextDate(date: date, months: months, days: daysOfMonth)
                return calendar.remainingDay(date: nextDate)
            }

            var nextDate = calendar.nextDate(date: date, months: months, days: daysOfMonth)

            while true {
                let timeInterval = calendar.dateInterval(date: nextDate, timeRange: timeRange)
                let remainingDay = calendar.remainingDay(date: nextDate)

                guard let result = timeInterval.intersection(with: remainingDay) else {
                    nextDate = calendar.nextDate(
                        date: calendar.startOfDay(date: date, dayOffset: 1),
                        months: months,
                        days: daysOfMonth
                    )
                    continue
                }
                return result
            }
        }
    }
}


fileprivate struct AirshipCalendar : Hashable, Equatable, Sendable {

    private let calendar: Calendar

    init(timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func startOfDay(date: Date, dayOffset: Int = 0) -> Date {
        guard dayOffset != 0 else {
            return calendar.startOfDay(for: date)
        }

        guard
            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: date)
        else {
            // Fallback to using hours offset. Should be fine for most
            // dates except for time zones with daylight savings on
            // transition days.
            return calendar.startOfDay(for: date + 24.hours)
        }

        return calendar.startOfDay(for: targetDate)
    }

    func endOfDay(date: Date, dayOffset: Int = 0) -> Date {
        let day = startOfDay(date: date, dayOffset: dayOffset)
        guard 
            let endOfDay =  calendar.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: day
            )
        else {
            // Fallback to using hours offset. Should be fine for most
            // dates except for time zones with daylight savings on
            // transition days.
            return day + 24.hours - 1.seconds
        }

        return endOfDay
    }

    private func date(date: Date, hour: Int, minute: Int) -> Date {
        guard
            let newDate = calendar.date(
                bySettingHour: hour, 
                minute: minute,
                second: 0,
                of:date
            )
        else {
            return startOfDay(date: date).advanced(by: hour.hours + minute.minutes)
        }

        return newDate
    }

    // Returns the date interval for the rest of the day
    func remainingDay(date: Date) -> DateInterval {
        return DateInterval(start: date, end: startOfDay(date: date, dayOffset: 1))
    }

    // Returns the date interval for the given date and timeRange. If the
    // date is passed the time range, the DateInterval will be for the next day.
    func dateInterval(date: Date, timeRange: ExecutionWindow.TimeRange) -> DateInterval {
        guard timeRange.start != timeRange.end else {
            let todayStart = self.date(
                date: startOfDay(date: date),
                hour: timeRange.startHour,
                minute: timeRange.startMinute
            )

            if (todayStart == date) {
                return DateInterval(start: todayStart, duration: 1)
            } else {
                let tomorrowStart = self.date(
                    date: startOfDay(date: date, dayOffset: 1),
                    hour: timeRange.startHour,
                    minute: timeRange.startMinute
                )
                return DateInterval(start: tomorrowStart, duration: 1)
            }
        }

        /// start: 23, end: 1

        let yesterdayInterval = DateInterval(
            start: self.date(
                date: startOfDay(date: date, dayOffset: -1),
                hour: timeRange.startHour,
                minute: timeRange.startMinute
            ),
            end: self.date(
                date: startOfDay(
                    date: date,
                    dayOffset: (timeRange.start > timeRange.end ? 0 : -1)
                ),
                hour: timeRange.endHour,
                minute: timeRange.endMinute
            )
        )

        if yesterdayInterval.isWithin(date: date) {
            return yesterdayInterval
        }

        let todayInterval = DateInterval(
            start: self.date(
                date: startOfDay(date: date),
                hour: timeRange.startHour,
                minute: timeRange.startMinute
            ),
            end: self.date(
                date: startOfDay(
                    date: date,
                    dayOffset: (timeRange.start > timeRange.end ? 1 : 0)
                ),
                hour: timeRange.endHour,
                minute: timeRange.endMinute
            )
        )

        if todayInterval.isWithin(date: date) || todayInterval.start >= date {
            return todayInterval
        }

        return DateInterval(
           start: self.date(
               date: startOfDay(date: date, dayOffset: 1),
               hour: timeRange.startHour,
               minute: timeRange.startMinute
           ),
           end: self.date(
               date: startOfDay(
                   date: date,
                   dayOffset: (timeRange.start > timeRange.end ? 2 : 1)
               ),
               hour: timeRange.endHour,
               minute: timeRange.endMinute
           )
       )
    }

    // Returns the current date if it matches the weekdays,
    // or the date of the start of the next requested weekday
    func nextDate(date: Date, weekdays: [Int]) -> Date {
        let currentWeekday = calendar.component(.weekday, from: date)
        let sortedWeekdays = weekdays.sorted()
        let targetWeekday = sortedWeekdays.first { $0 >= currentWeekday } ?? sortedWeekdays.first ?? currentWeekday

        // Mod it with number of days in the week
        let daysUntilNextSlot = if targetWeekday >= currentWeekday {
            targetWeekday - currentWeekday
        } else {
            targetWeekday + (7 - currentWeekday)
        }

        return if (daysUntilNextSlot > 0) {
            startOfDay(date: date, dayOffset: daysUntilNextSlot  )
        } else {
            date
        }
    }

    func nextDate(date: Date, months: [Int]? = nil, days: [Int]?) -> Date {
        guard months?.isEmpty == false || days?.isEmpty == false else {
            return date
        }

        let currentDay = calendar.component(.day, from: date)
        let currentMonth = calendar.component(.month, from: date)

        let sortedMonths = months?.sorted()
        let sortedDays = days?.sorted()

        let targetMonth = sortedMonths?.first { $0 >= currentMonth } ?? sortedMonths?.first ?? currentMonth
        var targetDay = sortedDays?.first(where: { $0 >= currentDay })

        // Our target month is this month
        if targetMonth == currentMonth {
            if let targetDay {
                return if targetDay == currentDay {
                    date
                } else {
                    startOfDay(date: date, dayOffset: (targetDay - currentDay))
                }
            } else if sortedDays?.isEmpty != false {
                return date
            }
        }

        // Pick the earliest day
        targetDay = sortedDays?.first ?? 1

        guard let sortedMonths, !sortedMonths.isEmpty else {
            return calendar.nextDate(
                after: date,
                matching: DateComponents(
                    day: targetDay
                ),
                matchingPolicy: .strict
            ) ?? Date.distantFuture
        }

        let results = sortedMonths.compactMap { month in
            let next = calendar.nextDate(
                after: date,
                matching: DateComponents(
                    month: month,
                    day: targetDay
                ),
                matchingPolicy: .strict
            )
            return if let next {
                startOfDay(date: next)
            } else {
                nil
            }
        }.sorted()

        return results.first ?? Date.distantFuture
    }
}

fileprivate extension DateInterval {
    func isWithin(date: Date) -> Bool {
        return contains(date) && self.end != date
    }
}
