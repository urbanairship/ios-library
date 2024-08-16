/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation

final class DisplayWindowTest: XCTestCase {
    
    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        
        if let zone = TimeZone(identifier: "GMT+3") {
            result.timeZone = zone
        }

        return result
    }
    
    func timeZoneHours() -> Int {
        let calendar = calendar
        let result = calendar.timeZone.secondsFromGMT() / 3600
        return result
    }
    
    private func resolveWindow(window: DisplayWindow, date: Date) -> DisplayWindowResult {
        return window.nextAvailability(date: date, customCalendar: calendar)
    }
    
    func testReturnNowOnMatch() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: []
        )
        
        XCTAssertEqual(resolveWindow(window: window, date: Date()), DisplayWindowResult.now)
    }
    
    func testReturnNextDayOnExcludeDaily() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let currentDate = Date()
        let startNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate))!
        let delay = startNextDay.timeIntervalSince(currentDate)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(delay))
    }
    
    func testReturnNextDayOnExcludeDailyFixedDate() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let currentDate = Date.fromMidnight(seconds: 100, calendar: calendar)
        let expected = 86400 - 100
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(Double(expected)))
    }
    
    func testReturnNextDayOnExcludeWeekly() {
        
        let currentDate = Date()
        let excludeMonth = calendar.component(.month, from: currentDate)
        let excludeDay = calendar.component(.weekday, from: currentDate)
        
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .weekly(months: [excludeMonth], daysOfWeek: [excludeDay]), timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let startNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate))!
        let delay = startNextDay.timeIntervalSince(currentDate)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(delay))
    }
    
    func testReturnNextDayOnExcludeMonthly() {
        
        let currentDate = Date()
        let excludeMonth = calendar.component(.month, from: currentDate)
        let excludeDay = calendar.component(.day, from: currentDate)
        
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .monthly(months: [excludeMonth], daysOfMonth: [excludeDay]), timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let startNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate))!
        let delay = startNextDay.timeIntervalSince(currentDate)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(delay))
    }
    
    func testRetryRespectsExcludeTimeWindow() {
        var window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .daily, timeWindow: .init(startHour: 1, endHour: 2), timeZoneOffset: timeZoneHours())
            ]
        )
        
        let currentDate = Date.fromMidnight(seconds: 100, calendar: calendar)
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.now)
        
        window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .daily, timeWindow: .init(startHour: 0, endHour: 1), timeZoneOffset: timeZoneHours())
            ]
        )
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(3500))
    }
    
    func testReturnNowOnAnyIncludeMatch() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil),
                .init(rule: .daily, timeWindow: .init(startHour: 0, endHour: 0), timeZoneOffset: 0)
            ],
            exclude: [
                .init(rule: .weekly(months: [13], daysOfWeek: []), timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let currentDate = Date(timeIntervalSince1970: 100)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.now)
    }
    
    func testReturnNextDayOnMissedInclude() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 0, endHour: 0, endMinute: 20), timeZoneOffset: nil)
            ],
            exclude: []
        )
        
        let currentDate = Date.fromMidnight(seconds: 0.5 * 60 * 60 + 60, calendar: calendar)
        let expected = 86400 - 1860
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(Double(expected)))
    }
    
    func testReturnTimeToTheIncludeOnMissedInclude() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 1, endHour: 2), timeZoneOffset: nil)
            ],
            exclude: []
        )
        
        let currentDate = Date.fromMidnight(seconds: 100, calendar: calendar)
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(3500))
    }
    
    func testReturnNowOnAnyIncludeTimeWindowMatch() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 1, endHour: 2), timeZoneOffset: nil),
                .init(rule: .daily, timeWindow: .init(startHour: 0, endHour: 1), timeZoneOffset: nil)
            ],
            exclude: []
        )
        
        let currentDate = Date.fromMidnight(seconds: 100, calendar: calendar)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.now)
    }
    
    func testReturnsNextSlotDelayOnInclude() {
        let window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 0, endHour: 1), timeZoneOffset: nil),
                .init(rule: .daily, timeWindow: .init(startHour: 2, endHour: 3), timeZoneOffset: nil)
            ],
            exclude: []
        )
        
        let currentDate = Date.fromMidnight(seconds: 60 * 60 + 100, calendar: calendar)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(3500))
    }
    
    func testIncludeRespectsTimeZone() {
        var window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 1, endHour: 2), timeZoneOffset: 0),
            ],
            exclude: []
        )
        
        let currentDate = Date.fromMidnight(seconds: 3660, calendar: calendar)
        let expected = 86400 - 3660
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(Double(expected)))
        
        window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: .init(startHour: 1, endHour: 2), timeZoneOffset: timeZoneHours()),
            ],
            exclude: []
        )
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.now)
    }
    
    func testExcludeRespectsTimeZone() {
        
        let currentDate = Date.fromMidnight(seconds: 20.5 * 60 * 60, calendar: calendar) // 20:30
        let excludeMonth = calendar.component(.month, from: currentDate)
        let excludeDay = calendar.component(.weekday, from: currentDate)
        
        var window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .weekly(months: [excludeMonth], daysOfWeek: [excludeDay]), timeWindow: nil, timeZoneOffset: nil)
            ]
        )
        
        let startNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate))!
        let delay = startNextDay.timeIntervalSince(currentDate)
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.retry(delay))
        
        window = DisplayWindow(
            include: [
                .init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)
            ],
            exclude: [
                .init(rule: .weekly(months: [excludeMonth], daysOfWeek: [excludeDay]), timeWindow: nil, timeZoneOffset: 8)
            ]
        )
        
        XCTAssertEqual(resolveWindow(window: window, date: currentDate), DisplayWindowResult.now)
    }
    
    func testExcludeTimezone() {
        let current = Date.fromMidnight(seconds: 21 * 60 * 60, calendar: calendar)
        
        let window = DisplayWindow(
            include: [.init(rule: .daily, timeWindow: nil, timeZoneOffset: nil)],
            exclude: [.init(rule: .daily, timeWindow: nil, timeZoneOffset: timeZoneHours() + 2)]
        )
        
        XCTAssertEqual(DisplayWindowResult.retry(3600), resolveWindow(window: window, date: current))
    }
}

extension Date {
    func local(calendar: Calendar) -> Date {
        return self.addingTimeInterval(Double(calendar.timeZone.secondsFromGMT()))
    }
    
    static func fromMidnight(seconds: TimeInterval, calendar: Calendar) -> Date {
        return Date(timeIntervalSince1970: 1704060000 + seconds - 3600)
    }
}

