import Foundation

public struct ExecutionWindow: Sendable, Equatable, Codable {
    var include: [Rule]?
    var exclude: [Rule]?

    struct Rule: Codable {
        let rule: ExecutionWindowRule
        let timeWindow: TimeWindow?
        let timeZoneOffset: Int?
    }

    struct TimeWindow: Codable {
        var startHour: Int
        var startMinute: Int?
        var endHour: Int
        var endMinute: Int?
    }
}

enum ExecutionWindowRule: Codable {
    case daily
    case weekly(months: [Int]? = nil, daysOfWeek: [Int])
    case monthly(months: [Int]? = nil, daysOfMonth: [Int])
}

enum ExecutionWindowResult: Equatable {
    case now
    case retry(TimeInterval)
}

extension ExecutionWindow {

    static func calendar(offsetSeconds: Int? = nil) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        
        if let offsetSeconds, let timeZone = TimeZone(secondsFromGMT: offsetSeconds) {
            calendar.timeZone = timeZone
        }
        
        return calendar
    }
    
    func nextAvailability(date: Date, customCalendar: Calendar? = nil) -> ExecutionWindowResult {
        let calendar = customCalendar ?? Self.calendar()
        let nextDay = calendar.nextDay(for: date) ?? date.addingTimeInterval(10 * 60)
        let tillNextDayDelay = nextDay.timeIntervalSince(date)
        
        if let exclude = excludes(date: date, local: calendar)?.first {
            let excludeCalendar = exclude.calendar(calendar)
            let nextDayDelay = (excludeCalendar.nextDay(for: date)?.timeIntervalSince(date)) ?? tillNextDayDelay
            let delay = exclude.timeWindow?.endOfSlot(date: date, calendar: excludeCalendar) ?? nextDayDelay
            return .retry(delay)
        }
        
        guard let includes = includes(date: date, local: calendar) else {
            return .retry(tillNextDayDelay)
        }
        
        var result = ExecutionWindowResult.retry(tillNextDayDelay)
        
        for slot in includes {
            guard let window = slot.timeWindow else {
                result = .now
                break
            }
            
            if window.contains(date: date, calendar: slot.calendar(calendar)) {
                result = .now
                break
            }
            
            if let delay = window.nextSlot(date: date, calendar: slot.calendar(calendar)) {
                result = .retry(delay)
                break
            }
        }
        
        return result
    }
    
    private func excludes(date: Date, local: Calendar) -> [Rule]? {
        return exclude?
            .map({ ($0, $0.calendar(local)) })
            .filter({ exclude, calendar in
                exclude.rule.isMatching(date: date, calendar: calendar)
            })
            .filter({ exclude, calendar in
                return exclude.timeWindow?.contains(date: date, calendar: calendar) ?? true
            })
            .map({ $0.0 })
            .sorted(by: <)
    }
    
    private func includes(date: Date, local: Calendar) -> [Rule]? {
        return include?
            .map({ ($0, $0.calendar(local)) })
            .filter({ include, calendar in
                include.rule.isMatching(date: date, calendar: calendar)
            })
            .map({ $0.0 })
            .sorted(by: <)
    }
}

extension ExecutionWindowRule {
    func isMatching(date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekly(let months, let daysOfWeek):
            let month = calendar.component(.month, from: date)
            let weekday = calendar.component(.weekday, from: date)
            return daysOfWeek.contains(weekday) && (months?.contains(month) ?? true)
        case .monthly(let months, let daysOfMonth):
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return daysOfMonth.contains(day) && (months?.contains(month) ?? true)
        }
    }
}

extension ExecutionWindow.TimeWindow {
    
    func contains(date: Date, calendar: Calendar) -> Bool {
        
        let midnight = calendar.startOfDay(for: date)
        
        let startDate = midnight.addingTimeInterval(fromMidnight(hour: startHour, minute: startMinute))
        let endDate = midnight.addingTimeInterval(fromMidnight(hour: endHour, minute: endMinute))
        
        return date >= startDate && date <= endDate
    }
    
    func nextSlot(date: Date, calendar: Calendar) -> TimeInterval? {
        let targetDate = calendar.startOfDay(for: date)
            .addingTimeInterval(fromMidnight(hour: startHour, minute: startMinute))
        
        guard targetDate > date else {
            //missed this include, try next one
            return nil
        }
        
        return targetDate.timeIntervalSince(date)
    }
    
    func endOfSlot(date: Date, calendar: Calendar) -> TimeInterval {
        let targetDate = calendar.startOfDay(for: date)
            .advanced(by: fromMidnight(hour: endHour, minute: endMinute))
        
        return targetDate.timeIntervalSince(date)
    }
    
    private func fromMidnight(hour: Int, minute: Int?) -> Double {
        return Double(hour * 60 * 60 + (minute ?? 0) * 60)
    }
    
    var startFromMidnight: Int {
        return startHour * 60 * 60 + (startMinute ?? 0) * 60
    }
}

extension ExecutionWindow.Rule: Comparable {
    static func < (lhs: ExecutionWindow.Rule, rhs: ExecutionWindow.Rule) -> Bool {
        if lhs.timeWindow == nil && rhs.timeWindow == nil {
            return false
        }
        
        guard let leftWindow = lhs.timeWindow else {
            return true
        }
        
        guard let rightWindow = rhs.timeWindow else {
            return false
        }
        
        return leftWindow.startFromMidnight < rightWindow.startFromMidnight
    }
    
    static func == (lhs: ExecutionWindow.Rule, rhs: ExecutionWindow.Rule) -> Bool {
        return lhs.timeWindow?.startHour == rhs.timeWindow?.startHour &&
            lhs.timeWindow?.startMinute == rhs.timeWindow?.startMinute
    }
    
    func calendar(_ local: Calendar) -> Calendar {
        guard let offset = timeZoneOffset else {
            return local
        }
        
        return ExecutionWindow.calendar(offsetSeconds: offset * 60 * 60)
    }
}

private extension Calendar {
    func nextDay(for date: Date) -> Date? {
        return self.date(byAdding: .day, value: 1, to: startOfDay(for: date))
    }
}
