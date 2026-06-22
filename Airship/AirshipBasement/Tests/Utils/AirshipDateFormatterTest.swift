/* Copyright Airship and Contributors */

import Testing
import Foundation
@_spi(AirshipInternal) @testable import AirshipBasement

struct AirshipDateFormatterTest {

    private var gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func components(for date: Date) -> DateComponents {
        gregorianUTC.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    // MARK: - Encoding

    @Test
    func encodeISO8601WithMilliseconds() {
        let date = AirshipDateFormatter.date(from: "2020-12-15T11:45:22.000Z")!
        #expect(AirshipDateFormatter.string(fromDate: date, format: .iso8601WithMilliseconds) == "2020-12-15T11:45:22.000Z")
    }

    @Test
    func encodeISO8601WithMillisecondsPreservesSubseconds() {
        let date = AirshipDateFormatter.date(from: "2020-12-15T11:45:22.123")!
        #expect(AirshipDateFormatter.string(fromDate: date, format: .iso8601WithMilliseconds) == "2020-12-15T11:45:22.123Z")
    }

    @Test
    func encodeISO8601() {
        let date = AirshipDateFormatter.date(from: "2020-12-15T11:45:22Z")!
        #expect(AirshipDateFormatter.string(fromDate: date, format: .iso8601) == "2020-12-15T11:45:22Z")
    }

    // MARK: - Parsing: UTC variants

    @Test(arguments: [
        ("2020-12-15T11:45:22.000Z",       "millis with Z"),
        ("2020-12-15T11:45:22.000+00:00",  "millis with +00:00"),
        ("2020-12-15T11:45:22.000-00:00",  "millis with -00:00"),
        ("2020-12-15T11:45:22+00:00",      "no millis with +00:00"),
        ("2020-12-15T11:45:22-00:00",      "no millis with -00:00"),
        ("2020-12-15T11:45:22Z",           "no millis with Z"),
        ("2020-12-15T11:45:22",            "no millis no Z"),
        ("2020-12-15 11:45:22",            "space delimiter"),
    ])
    func parseUTCVariants(string: String, label: String) throws {
        let date = try #require(AirshipDateFormatter.date(from: string), "Failed to parse \(label): \(string)")
        let c = components(for: date)
        #expect(c.year == 2020, "\(label)")
        #expect(c.month == 12, "\(label)")
        #expect(c.day == 15, "\(label)")
        #expect(c.hour == 11, "\(label)")
        #expect(c.minute == 45, "\(label)")
        #expect(c.second == 22, "\(label)")
    }

    @Test
    func parseNonZeroOffset() throws {
        // 2020-12-15T13:45:22+02:00 == 2020-12-15T11:45:22Z
        let date = try #require(AirshipDateFormatter.date(from: "2020-12-15T13:45:22.000+02:00"))
        let c = components(for: date)
        #expect(c.hour == 11)
        #expect(c.minute == 45)
        #expect(c.second == 22)
    }

    @Test
    func parseSubseconds() throws {
        let withoutMillis = try #require(AirshipDateFormatter.date(from: "2020-12-15T11:45:22"))
        let withMillis = try #require(AirshipDateFormatter.date(from: "2020-12-15T11:45:22.123"))
        #expect(abs(withMillis.timeIntervalSince(withoutMillis) - 0.123) < 0.0001)
    }

    /// ISO 8601 treats the fractional part as a decimal of a second:
    /// `.5` == `.50` == `.500` == 500 ms past the second.
    @Test(arguments: [
        ("2020-12-15T11:45:22.5",   0.5),
        ("2020-12-15T11:45:22.50",  0.5),
        ("2020-12-15T11:45:22.500", 0.5),
        ("2020-12-15T11:45:22.12",  0.12),
        ("2020-12-15T11:45:22.123", 0.123),
        ("2020-12-15T11:45:22.5Z",  0.5),
        ("2020-12-15T11:45:22.12Z", 0.12),
    ])
    func parseFractionalSecondsAsDecimal(string: String, expectedSubseconds: TimeInterval) throws {
        let base = try #require(AirshipDateFormatter.date(from: "2020-12-15T11:45:22"))
        let parsed = try #require(AirshipDateFormatter.date(from: string), "Failed to parse: \(string)")
        let delta = parsed.timeIntervalSince(base)
        #expect(abs(delta - expectedSubseconds) < 0.0001, "\(string): expected +\(expectedSubseconds)s, got +\(delta)s")
    }

    // MARK: - Parsing: partial formats

    @Test(arguments: [
        ("2020",             2020, 1,  1,  0,  0,  0),
        ("2020-12",          2020, 12, 1,  0,  0,  0),
        ("2020-12-15",       2020, 12, 15, 0,  0,  0),
        ("2020-12-15T11",    2020, 12, 15, 11, 0,  0),
        ("2020-12-15 11",    2020, 12, 15, 11, 0,  0),
        ("2020-12-15T11:45", 2020, 12, 15, 11, 45, 0),
        ("2020-12-15 11:45", 2020, 12, 15, 11, 45, 0),
        ("2020-12-15T11:45:22", 2020, 12, 15, 11, 45, 22),
        ("2020-12-15 11:45:22", 2020, 12, 15, 11, 45, 22),
    ])
    func parsePartialFormats(
        string: String,
        year: Int, month: Int, day: Int,
        hour: Int, minute: Int, second: Int
    ) throws {
        let date = try #require(AirshipDateFormatter.date(from: string), "Failed to parse: \(string)")
        let c = components(for: date)
        #expect(c.year == year, "year for \(string)")
        #expect(c.month == month, "month for \(string)")
        #expect(c.day == day, "day for \(string)")
        #expect(c.hour == hour, "hour for \(string)")
        #expect(c.minute == minute, "minute for \(string)")
        #expect(c.second == second, "second for \(string)")
    }

    // MARK: - Parsing: invalid

    @Test
    func parseInvalidReturnsNil() {
        #expect(AirshipDateFormatter.date(from: "not-a-date") == nil)
        #expect(AirshipDateFormatter.date(from: "") == nil)
    }
}
