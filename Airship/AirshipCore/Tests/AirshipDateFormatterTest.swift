/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

class AirshipDateFormatterTest: XCTestCase {

    private var gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    
    func components(for date: Date) -> DateComponents {
        return gregorianUTC.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    func validateDateFormatter(_ format: AirshipDateFormatter.Format, withFormatString formatString: String) {
        guard let date = AirshipDateFormatter.date(fromISOString: formatString) else {
            XCTFail("Failed to parse date from format string")
            return
        }

        let components = self.components(for: date)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 22)

        XCTAssertEqual(formatString, AirshipDateFormatter.string(fromDate: date, format: format))
    }

    func testISODateFormatterUTC() {
        validateDateFormatter(.iso, withFormatString: "2020-12-15 11:45:22")
    }

    func testISODateFormatterUTCWithDelimiter() {
        validateDateFormatter(.isoDelimitter, withFormatString: "2020-12-15T11:45:22")
    }

    func testParseISO8601FromTimeStamp() {
        // yyyy
        var date = AirshipDateFormatter.date(fromISOString: "2020")!
        var components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM
        date = AirshipDateFormatter.date(fromISOString: "2020-12")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15T11")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd hh
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15 11")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh:mm
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15T11:45")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd hh:mm
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15 11:45")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh:mm:ss
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15T11:45:22")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 22)

        // yyyy-MM-dd hh:mm:ss
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15T11:45:22")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 22)
        let dateWithoutSubseconds = date

        // yyyy-MM-ddThh:mm:ss.SSS
        date = AirshipDateFormatter.date(fromISOString: "2020-12-15T11:45:22.123")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 22)
        let seconds = date.timeIntervalSince(dateWithoutSubseconds)
        XCTAssertEqual(seconds, 0.123, accuracy: 0.0001)
    }
}
