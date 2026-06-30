/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore

struct ExectutionWindowTest {
    private var defaultTimeZone: TimeZone = TimeZone(secondsFromGMT: 0)!

    private var calendar: Calendar  {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = defaultTimeZone
        return calendar
    }

    // Jan 1, 2024 leap year!
    private var referenceDate: Date {
        calendar.date(
            from: DateComponents(
                year: 2024,
                month: 1,
                day: 1,
                hour: 0,
                minute: 0,
                second: 0
            )
        )!
    }

    @Test
    func testCodable() throws {
        let json = """
        {
          "include": [
            {
              "type": "weekly",
              "days_of_week": [1,2,3,4,5],
              "time_range": {
                "start_hour": 8,
                "start_minute": 30,
                "end_hour": 5,
                "end_minute": 59
              }
            },
          ],
          "exclude": [
            {
              "type": "daily",
              "time_range": {
                "start_hour": 12,
                "start_minute": 0,
                "end_hour": 13,
                "end_minute": 0
              },
              "time_zone": {
                "type": "local"
              }
            },
            {
              "type": "monthly",
              "months": [12],
              "days_of_month": [24, 31]
            },
            {
              "type": "monthly",
              "months": [1],
              "days_of_month": [1]
            }
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .weekly(daysOfWeek: [1,2,3,4,5], timeRange: .init(startHour: 8, startMinute: 30, endHour: 5, endMinute: 59))
            ],
            exclude: [
                .daily(timeRange: .init(startHour: 12, startMinute: 0, endHour: 13, endMinute: 0), timeZone: .local),
                .monthly(months: [12], daysOfMonth: [24, 31]),
                .monthly(months: [1], daysOfMonth: [1]),
            ]
        )

        try verify(json: json, expected: expected)
    }

    @Test
    func testDaily() throws {
        let json = """
        {
          "include": [
            {
              "type": "daily",
              "time_range": {
                "start_hour": 12,
                "start_minute": 1,
                "end_hour": 13,
                "end_minute": 2
              },
              "time_zone": {
                "type": "utc"
              }
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .daily(timeRange: .init(startHour: 12, startMinute: 1, endHour: 13, endMinute: 2), timeZone: .utc)
            ]
        )

        try verify(json: json, expected: expected)
    }

    @Test
    func testInvalidDaily() throws {
        let json = """
        {
          "include": [
            {
              "type": "daily"
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidTimeRange() throws {
        let json = """
        {
          "include": [
            {
              "type": "daily",
              "time_range": {
                startMinute: -1,
                startHour: 12,
                endMinute: 0,
                endHour: 1
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidTimeZoneType() throws {
        let json = """
        {
          "include": [
            {
              "type": "daily",
              "time_range": {
                "start_hour": 12,
                "start_minute": 1,
                "end_hour": 13,
                "end_minute": 2
              },
              "time_zone": {
                "type": "something"
              }
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testTimeZoneIdentifiers() throws {
        let json = """
        {
          "include": [
            {
              "type": "daily",
              "time_range": {
                "start_hour": 12,
                "start_minute": 1,
                "end_hour": 13,
                "end_minute": 2
              },
              "time_zone": {
                "type": "identifiers",
                "identifiers": ["America/Los_Angeles", "Africa/Abidjan"],
                "on_failure": "skip",
              }
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(startHour: 12, startMinute: 1, endHour: 13, endMinute: 2),
                    timeZone: .identifiers(["America/Los_Angeles", "Africa/Abidjan"], onFailure: .skip)
                )
            ]
        )

        try verify(json: json, expected: expected)

    }

    @Test
    func testMonthly() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "months": [1, 12],
              "days_of_month": [1, 31]
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .monthly(months: [1, 12], daysOfMonth: [1, 31])
            ]
        )

        try verify(json: json, expected: expected)
    }

    @Test
    func testMonthlyOnlyMonths() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "months": [1, 12]
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .monthly(months: [1, 12])
            ]
        )

        try verify(json: json, expected: expected)
    }

    @Test
    func testMonthlyOnlyDays() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "days_of_month": [1, 31]
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .monthly(daysOfMonth: [1, 31])
            ]
        )

        try verify(json: json, expected: expected)
    }

    @Test
    func testInvalidMonthly() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly"
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidMonthlyEmpty() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "days_of_month": [],
              "months": []
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidMonthlyMonthsBelow1() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "months": [0]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidMonthlyMonthAbove12() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "months": [13]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidMonthlyDaysAbove31() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "days_of_month": [32]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testInvalidMonthlyDaysBelow1() throws {
        let json = """
        {
          "include": [
            {
              "type": "monthly",
              "days_of_month": [0]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testWeekly() throws {
        let json = """
        {
          "include": [
            {
              "type": "weekly",
              "days_of_week": [1, 7]
            },
          ]
        }
        """

        let expected = try ExecutionWindow(
            include: [
                .weekly(daysOfWeek: [1, 7])
            ]
        )

        try verify(json: json, expected: expected)
    }


    @Test
    func testWeeklyInvalidEmptyDaysOfWeek() throws {
        let json = """
        {
          "include": [
            {
              "type": "weekly",
              "days_of_week": []
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testWeeklyInvalidEmptyDaysOfWeekBelow1() throws {
        let json = """
        {
          "include": [
            {
              "type": "weekly",
              "days_of_week": [0]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testWeeklyInvalidEmptyDaysOfAbove7() throws {
        let json = """
        {
          "include": [
            {
              "type": "weekly",
              "days_of_week": [8]
            },
          ]
        }
        """

        do {
            _ = try JSONDecoder().decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testReturnNowOnMatch() throws {
        let window = try ExecutionWindow(
            include: [
                .daily(timeRange: .init(startHour: 0, endHour: 23))
            ],
            exclude: []
        )

        #expect(windowAvailibility(window, date: referenceDate) == .now)
    }

    @Test
    func testEmptyWindow() throws {
        let window = try ExecutionWindow()
        #expect(windowAvailibility(window, date: Date()) == .now)
    }

    @Test
    func testIncludeTimeRangeSameStartAndEnd() throws {
        var date = referenceDate
        let window = try ExecutionWindow(
            include: [
                .daily(timeRange: .init(startHour: 0, endHour: 0))
            ]
        )

        #expect(windowAvailibility(window, date: referenceDate) == .now)

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(1.days - 1.seconds))

        date -= 2.seconds
        #expect(windowAvailibility(window, date: date) == .retry(1.seconds))
    }

    @Test
    func testIncludeTimeRange() throws {
        var date = referenceDate
        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 3,
                        endHour: 4
                    )
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(3.hours))

        date += 3.hours
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.hours
        #expect(windowAvailibility(window, date: date) == .retry(23.hours))
    }

    @Test
    func testExcludeTimeRangeSameStartAndEnd() throws {
        var date = referenceDate
        let window = try ExecutionWindow(
            exclude: [
                .daily(timeRange: .init(startHour: 0, endHour: 0))
            ]
        )
        #expect(windowAvailibility(window, date: date) == .retry(1.seconds))

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date -= 2.seconds
        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testExcludeEndOfTimeRange() throws {
        var date = referenceDate + 3.hours
        let window = try ExecutionWindow(
            exclude: [
                .daily(
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    )
                )
            ]
        )
        
        #expect(windowAvailibility(window, date: date) == .retry(21.hours))

        date += 21.hours
        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testExcludeTimeRangeWrap() throws {
        var date = calendar.date(
            from: DateComponents(
                year: 2024,
                month: 1,
                day: 1,
                hour: 23,
                minute: 0,
                second: 0
            )
        )!

        let window = try ExecutionWindow(
            exclude: [
                .daily(
                    timeRange: .init(
                        startHour: 23,
                        endHour: 1
                    )
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(2.hours))

        date += 1.hours
        #expect(windowAvailibility(window, date: date) == .retry(1.hours))

        date += 1.hours
        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testIncludeAndExcludeSameRule() throws {
        let date = referenceDate + 3.hours
        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    )
                )
            ],
            exclude: [
                .daily(
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    )
                )
            ]
        )

        let startNextDay = calendar.startOfDay(for: date + 1.days)
        let delay = startNextDay.timeIntervalSince(date)

        #expect(windowAvailibility(window, date: date) == .retry(delay))
    }

    @Test
    func testIncludeWeekly() throws {
        var date = calendar.date(bySetting: .weekday, value: 4, of: referenceDate)!
        let window = try ExecutionWindow(
            include: [
                .weekly(daysOfWeek: [3, 5])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(1.days))

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(4.days))

        date += 3.days
        #expect(windowAvailibility(window, date: date) == .retry(1.days))

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testIncludeWeeklyTimeRange() throws {
        var date = calendar.date(bySetting: .weekday, value: 4, of: referenceDate)!
        let window = try ExecutionWindow(
            include: [
                .weekly(
                    daysOfWeek: [3, 5],
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    )
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(1.days + 3.hours))

        date += 1.days + 3.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(1.seconds))

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date += 21.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(4.days + 3.hours))
    }

    @Test
    func testIncludeWeeklyTimeRangeWithTimeZone() throws {
        var date = calendar.date(bySetting: .weekday, value: 4, of: referenceDate)!
        let window = try ExecutionWindow(
            include: [
                .weekly(
                    daysOfWeek: [3, 5],
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    ),
                    timeZone: .secondsFromGMT(Int(1.hours))
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(1.days + 2.hours))

        date += 1.days + 2.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(1.seconds))

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date += 21.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(4.days + 3.hours))
    }

    @Test
    func testExcludeWeeklyTimeRange() throws {
        var date = calendar.date(bySetting: .weekday, value: 4, of: referenceDate)!
        let window = try ExecutionWindow(
            exclude: [
                .weekly(
                    daysOfWeek: [3, 5],
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    )
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days + 3.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(21.hours))

        date += 21.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .retry(1.seconds))

        date += 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testIncludeMonthly() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(months: [2, 4], daysOfMonth: [15, 10])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(40.days))

        date += 40.days
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(4.days))

        date += 4.days
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(54.days))

        date += 55.days
        #expect(windowAvailibility(window, date: date) == .retry(4.days))

        date += 5.days
        #expect(windowAvailibility(window, date: date) == .retry(300.days))
    }

    @Test
    func testMonthlyNoMonthsAfterDay() throws {
        let date = calendar.date(bySetting: .day, value: 16, of: referenceDate)!

        let window = try ExecutionWindow(
            include: [
                .monthly(daysOfMonth: [15])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(30.days))
    }

    @Test
    func testMonthlyNextMonth() throws {
        // Feb 16
        var date = calendar.date(bySetting: .month, value: 2, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 16, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(months: [1], daysOfMonth: [15]),
                .monthly(months: [3], daysOfMonth: [2, 3])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(15.days))
    }

    @Test
    func testMonthlyNextMonthNoDays() throws {
        // Feb 16
        var date = calendar.date(bySetting: .month, value: 2, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 16, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(months: [1, 3])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(14.days))
    }

    @Test
    func testMonthlyNextYear() throws {
        // Feb 15
        var date = calendar.date(bySetting: .month, value: 2, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 15, of: date)!


        let window = try ExecutionWindow(
            include: [
                .monthly(months: [1], daysOfMonth: [14])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(334.days))
    }

    @Test
    func testIncludeMonthlyWithTimeZone() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(
                    months: [2, 4],
                    daysOfMonth: [15, 10],
                    timeZone: .secondsFromGMT(Int(7.hours))
                )
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(40.days - 7.hours))

        date += 40.days - 7.hours
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(4.days))

        date += 4.days
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(54.days))

        date += 55.days
        #expect(windowAvailibility(window, date: date) == .retry(4.days))

        date += 5.days
        #expect(windowAvailibility(window, date: date) == .retry(300.days))
    }


    @Test
    func testImpossibleMonthlyInclude() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                // can't happen
                .monthly(months: [2], daysOfMonth: [31], timeRange: .init(startHour: 5, endHour: 23))
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(Date.distantFuture.timeIntervalSince(referenceDate) + 5.hours))
    }

    @Test
    func testMonthlySkipsInvalidMonths() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                // can't happen
                .monthly(months: [2, 10], daysOfMonth: [31])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(304.days))
    }

    @Test
    func testImpossibleMonthlyExclude() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            exclude: [
                // can't happen
                .monthly(months: [2], daysOfMonth: [31])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .now)
    }

    @Test
    func testMonthlyWithoutMonths() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(daysOfMonth: [31])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(30.days))

        date += 31.days
        #expect(windowAvailibility(window, date: date) == .retry(30.days))
    }

    @Test
    func testMonthlyWithOnlyMonths() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                .monthly(months: [10, 12])
            ]
        )

        #expect(windowAvailibility(window, date: date) == .retry(274.days))

        date += 274.days
        #expect(windowAvailibility(window, date: date) == .now)

        for _ in 0..<30 {
            date += 1.days
            #expect(windowAvailibility(window, date: date) == .now)
        }

        date += 1.days
        #expect(windowAvailibility(window, date: date) == .retry(30.days))
    }

    @Test
    func testEmptyMonthlyIncludeThrows() throws {
        do {
            _ = try ExecutionWindow(
                include: [
                    .monthly()
                ]
            )
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testEmptyMonthlyExcludeThrows() throws {
        do {
            _ = try ExecutionWindow(
                exclude: [
                    .monthly()
                ]
            )
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testComplexRule() throws {
        var date = calendar.date(bySetting: .month, value: 1, of: referenceDate)!
        date = calendar.date(bySetting: .day, value: 1, of: date)!

        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(startHour: 1, endHour: 2),
                    timeZone: .secondsFromGMT(Int(1.hours))
                ),
                .weekly(
                    daysOfWeek: [5],
                    timeRange: .init(
                        startHour: 3,
                        endHour: 5
                    ),
                    timeZone: .utc
                ),
                .monthly(months: [2, 4], daysOfMonth: [2], timeRange: .init(startHour: 10, endHour: 22))
            ],
            exclude: [
                .monthly(months: [1, 3, 5, 7, 9, 11])
            ]
        )

        // Exclude monthly without days is only 1 day at a time
        #expect(windowAvailibility(window, date: date) == .retry(1.days))

        for _ in 0..<30 {
            date += 1.days
            #expect(windowAvailibility(window, date: date) == .retry(1.days))
        }

        // Feb 1
        date += 1.days
        // Timezone offset for the daily rule is 1, so its makes it [0-1]
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.hours
        // 2 hour until weekly rule for DOW 5
        #expect(windowAvailibility(window, date: date) == .retry(2.hours))

        date += 2.hours
        #expect(windowAvailibility(window, date: date) == .now)

        date += 2.hours
        // 19 hours until the daily rule again
        #expect(windowAvailibility(window, date: date) == .retry(19.hours))

        date += 19.hours
        #expect(windowAvailibility(window, date: date) == .now)

        date += 1.hours
        // 9 hours until the monthly rule
        #expect(windowAvailibility(window, date: date) == .retry(9.hours))

        date += 9.hours
        #expect(windowAvailibility(window, date: date) == .now)

        date += 12.hours - 1.seconds
        #expect(windowAvailibility(window, date: date) == .now)

        date +=  1.seconds
        // 2 hour until the daily rule again
        #expect(windowAvailibility(window, date: date) == .retry(2.hours))
    }


    @Test
    mutating func testTransitionOutOfDST() throws {
        // Sun March 10 2024 we transition from PDT to PST
        self.defaultTimeZone = TimeZone(identifier: "America/Los_Angeles")!

        let midnightOf = calendar.date(
            from: DateComponents(
                timeZone: self.defaultTimeZone,
                year: 2024,
                month: 3,
                day: 10,
                hour: 0,
                minute: 0,
                second: 0
            )
        )!


        // Sun March 10 2024
        let transition = calendar.date(
            from: DateComponents(
                timeZone: self.defaultTimeZone,
                year: 2024,
                month: 3,
                day: 10,
                hour: 3,
                minute: 0,
                second: 0
            )
        )!

        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 2,
                        endHour: 4
                    )
                )
            ]
        )

        // 12:00 PST
        #expect(windowAvailibility(window, date: midnightOf) == .retry(2.hours))

        // 3:00 PDT
        #expect(windowAvailibility(window, date: transition) == .now)

        // 4:00 PDT
        #expect(windowAvailibility(window, date: transition + 1.hours) == .retry(22.hours))
    }

    @Test
    mutating func testTransitionToDST() throws {
        // Sun Nov 3 2024 we transition from PST to PDT
        self.defaultTimeZone = TimeZone(identifier: "America/Los_Angeles")!

        let midnightOf = calendar.date(
            from: DateComponents(
                timeZone: self.defaultTimeZone,
                year: 2024,
                month: 11,
                day: 3,
                hour: 0,
                minute: 0,
                second: 0
            )
        )!


        // Sun March 10 2024
        let transition = calendar.date(
            from: DateComponents(
                timeZone: self.defaultTimeZone,
                year: 2024,
                month: 3,
                day: 10,
                hour: 1,
                minute: 0,
                second: 0
            )
        )!

        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 2,
                        endHour: 4
                    )
                )
            ]
        )

        // 12:00 PDT
        #expect(windowAvailibility(window, date: midnightOf) == .retry(3.hours))

        // 1:00 PST
        #expect(windowAvailibility(window, date: transition) == .retry(1.hours))

        // 2:00 PDT
        #expect(windowAvailibility(window, date: transition + 1.hours) == .now)
    }

    @Test
    func testErrorTimeZoneIdentifiersFailed() throws {
        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 3,
                        endHour: 0
                    ),
                    timeZone: .identifiers(["Does not exist"], onFailure: .error)
                )
            ]
        )

        do {
            _ = try window.nextAvailability(date: referenceDate)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testSkipTimeZoneIdentifiersFailed() throws {
        let window = try ExecutionWindow(
            include: [
                .daily(
                    timeRange: .init(
                        startHour: 0,
                        endHour: 10
                    ),
                    timeZone: .identifiers(["Does not exist"], onFailure: .skip)
                )
            ]
        )

        let result = try window.nextAvailability(date: referenceDate)
        #expect(result == .now)
    }

    private func windowAvailibility(_ window: ExecutionWindow, date: Date) -> ExecutionWindowResult {
        try! window.nextAvailability(date: date, currentTimeZone: defaultTimeZone)
    }

    func verify(json: String, expected: ExecutionWindow, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let fromJSON = try decoder.decode(ExecutionWindow.self, from: json.data(using: .utf8)!)
        #expect(fromJSON == expected, sourceLocation: sourceLocation)

        let roundTrip = try decoder.decode(ExecutionWindow.self, from: try encoder.encode(fromJSON))
        #expect(roundTrip == fromJSON, sourceLocation: sourceLocation)
    }
}

extension Date {
    func local(calendar: Calendar) -> Date {
        return self.advanced(by: Double(calendar.timeZone.secondsFromGMT()))
    }
    
    static func fromMidnight(seconds: TimeInterval, calendar: Calendar) -> Date {
        return Date(timeIntervalSince1970: 1704060000 + seconds - 3600)
    }
}

fileprivate extension ExecutionWindow.TimeZone {
    static func secondsFromGMT(_ seconds: Int) -> ExecutionWindow.TimeZone {
        let timeZoneID = TimeZone(secondsFromGMT: seconds)!.identifier
        return .identifiers([timeZoneID], onFailure: .error)
    }
}


fileprivate extension Int {
    var days: TimeInterval {
        return TimeInterval(self) * 60 * 60 * 24
    }

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
