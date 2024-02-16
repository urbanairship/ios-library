/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipUtilsTest: XCTestCase {

    private var gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testConnectionType() {
        let possibleConnectionTypes = ["cell", "wifi", "none"]
        let connectionType = AirshipUtils.connectionType()
        XCTAssertTrue(possibleConnectionTypes.contains(connectionType))
    }

    func testDeviceModelName() {
        let deviceModelName = AirshipUtils.deviceModelName()!
        XCTAssertNotNil(deviceModelName)
        let validSimulatorModels = ["x86_64", "arm64", "mac"]
        XCTAssertTrue(validSimulatorModels.contains(deviceModelName))
    }

    func components(for date: Date) -> DateComponents {
        return gregorianUTC.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    func validateDateFormatter(_ dateFormatter: DateFormatter, withFormatString formatString: String) {
        guard let date = dateFormatter.date(from: formatString) else {
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

        XCTAssertEqual(formatString, dateFormatter.string(from: date))
    }

    func testISODateFormatterUTC() {
        validateDateFormatter(AirshipUtils.isoDateFormatterUTC(), withFormatString: "2020-12-15 11:45:22")
    }

    func testISODateFormatterUTCWithDelimiter() {
        validateDateFormatter(AirshipUtils.isoDateFormatterUTCWithDelimiter(), withFormatString: "2020-12-15T11:45:22")
    }

    func testParseISO8601FromTimeStamp() {
        // yyyy
        var date = AirshipUtils.parseISO8601Date(from: "2020")!
        var components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM
        date = AirshipUtils.parseISO8601Date(from: "2020-12")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15T11")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd hh
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15 11")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh:mm
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15T11:45")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd hh:mm
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15 11:45")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 0)

        // yyyy-MM-dd'T'hh:mm:ss
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15T11:45:22")!
        components = self.components(for: date)
        XCTAssertNotNil(components)
        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 22)

        // yyyy-MM-dd hh:mm:ss
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15T11:45:22")!
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
        date = AirshipUtils.parseISO8601Date(from: "2020-12-15T11:45:22.123")!
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

    func testSignedToken() throws {

        XCTAssertEqual(
            "VWtkZq18HZM3GWzD/q27qPSVszysSyoQfQ6tDEAcAko=",
            try! AirshipUtils.generateSignedToken(secret: "appSecret", tokenParams: ["appKey", "some channel"])
        )

        XCTAssertEqual(
            "Npyqy5OZxMEVv4bt64S3aUE4NwUQVLX50vGrEegohFE=",
            try! AirshipUtils.generateSignedToken(secret: "test-app-secret", tokenParams: ["test-app-key", "channel ID"])
        )
    }

    func testIsSilentPush() {
        let emptyNotification: [String: Any] = [
            "aps": [
                "content-available": 1
            ]
        ]

        let emptyAlert: [String: Any] = [
            "aps": [
                "alert": ""
            ]
        ]

        let emptyLocKey: [String: Any] = [
            "aps": [
                "alert": [
                    "loc-key": ""
                ]
            ]
        ]

        let emptyBody: [String: Any] = [
            "aps": [
                "alert": [
                    "body": ""
                ]
            ]
        ]

        XCTAssertTrue(AirshipUtils.isSilentPush(emptyNotification))
        XCTAssertTrue(AirshipUtils.isSilentPush(emptyAlert))
        XCTAssertTrue(AirshipUtils.isSilentPush(emptyLocKey))
        XCTAssertTrue(AirshipUtils.isSilentPush(emptyBody))
    }

    func testIsSilentPushNo() {
        let alertNotification: [String: Any] = [
            "aps": [
                "alert": "hello world"
            ]
        ]

        let badgeNotification: [String: Any] = [
            "aps": [
                "badge": 2
            ]
        ]

        let soundNotification: [String: Any] = [
            "aps": [
                "sound": "cat"
            ]
        ]

        let notification: [String: Any] = [
            "aps": [
                "alert": "hello world",
                "badge": 2,
                "sound": "cat"
            ]
        ]

        let locKeyNotification: [String: Any] = [
            "aps": [
                "alert": [
                    "loc-key": "cool"
                ]
            ]
        ]

        let bodyNotification: [String: Any] = [
            "aps": [
                "alert": [
                    "body": "cool"
                ]
            ]
        ]

        XCTAssertFalse(AirshipUtils.isSilentPush(alertNotification))
        XCTAssertFalse(AirshipUtils.isSilentPush(badgeNotification))
        XCTAssertFalse(AirshipUtils.isSilentPush(soundNotification))
        XCTAssertFalse(AirshipUtils.isSilentPush(notification))
        XCTAssertFalse(AirshipUtils.isSilentPush(locKeyNotification))
        XCTAssertFalse(AirshipUtils.isSilentPush(bodyNotification))
    }

    func testIsAlertingPush() {
        let alertNotification: [String: Any] = [
            "aps": [
                "alert": "hello world"
            ]
        ]

        let notification: [String: Any] = [
            "aps": [
                "alert": "hello world",
                "badge": 2,
                "sound": "cat"
            ]
        ]

        let locKeyNotification: [String: Any] = [
            "aps": [
                "alert": [
                    "loc-key": "cool"
                ]
            ]
        ]

        let bodyNotification: [String: Any] = [
            "aps": [
                "alert": [
                    "body": "cool"
                ]
            ]
        ]

        XCTAssertTrue(AirshipUtils.isAlertingPush(alertNotification))
        XCTAssertTrue(AirshipUtils.isAlertingPush(notification))
        XCTAssertTrue(AirshipUtils.isAlertingPush(locKeyNotification))
        XCTAssertTrue(AirshipUtils.isAlertingPush(bodyNotification))
    }

    func testIsAlertingPushNo() {
        let emptyNotification: [String: Any] = [
            "aps": [
                "content-available": 1
            ]
        ]

        let emptyAlert: [String: Any] = [
            "aps": [
                "alert": ""
            ]
        ]

        let emptyLocKey: [String: Any] = [
            "aps": [
                "alert": [
                    "loc-key": ""
                ]
            ]
        ]

        let emptyBody: [String: Any] = [
            "aps": [
                "alert": [
                    "body": ""
                ]
            ]
        ]

        let badgeNotification: [String: Any] = [
            "aps": [
                "badge": 2
            ]
        ]

        let soundNotification: [String: Any] = [
            "aps": [
                "sound": "cat"
            ]
        ]

        XCTAssertFalse(AirshipUtils.isAlertingPush(emptyNotification))
        XCTAssertFalse(AirshipUtils.isAlertingPush(emptyAlert))
        XCTAssertFalse(AirshipUtils.isAlertingPush(emptyLocKey))
        XCTAssertFalse(AirshipUtils.isAlertingPush(emptyBody))
        XCTAssertFalse(AirshipUtils.isAlertingPush(badgeNotification))
        XCTAssertFalse(AirshipUtils.isAlertingPush(soundNotification))
    }

    func testParseURL() {
        var originalUrl = "https://advswift.com/api/v1?page=url+components"
        var url = AirshipUtils.parseURL(originalUrl)
        XCTAssertNotNil(url)
        XCTAssertEqual(originalUrl, url?.absoluteString)

        originalUrl = "rtlmost://szakaszó.com/main/típus/v1?page=azonosító"
        url = AirshipUtils.parseURL(originalUrl)
        XCTAssertNotNil(url)

        if #available(iOS 17.0, tvOS 17.0, *) {
            let encodedUrl = "rtlmost://xn--szakasz-r0a.com/main/t%C3%ADpus/v1?page=azonos%C3%ADt%C3%B3"
            XCTAssertEqual(encodedUrl, url?.absoluteString)
        } else {
            let encodedUrl = "rtlmost://szakasz%C3%B3.com/main/t%C3%ADpus/v1?page=azonos%C3%ADt%C3%B3"
            XCTAssertEqual(encodedUrl, url?.absoluteString)
        }
    }
}
