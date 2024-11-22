/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipUtilsTest: XCTestCase {

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

    func testEmailValidationValidEmails() {
        XCTAssertTrue("simple@example.com".airshipIsValidEmail())
        XCTAssertTrue("very.common@example.com".airshipIsValidEmail())
        XCTAssertTrue("disposable.style.email.with+symbol@example.com".airshipIsValidEmail())
        XCTAssertTrue("other.email-with-hyphen@example.com".airshipIsValidEmail())
        XCTAssertTrue("fully-qualified-domain@example.com".airshipIsValidEmail())
        XCTAssertTrue("user.name+tag+sorting@example.com".airshipIsValidEmail())
        XCTAssertTrue("x@y.z".airshipIsValidEmail())
        XCTAssertTrue("user123@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user.name@domain.com".airshipIsValidEmail())
        XCTAssertTrue("a@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user@sub.domain.com".airshipIsValidEmail())
        XCTAssertTrue("user-name@domain.com".airshipIsValidEmail())
    }

    func testEmailValidationInvalidEmails() {
        XCTAssertFalse("".airshipIsValidEmail())
        XCTAssertFalse(" ".airshipIsValidEmail())
        XCTAssertFalse("@".airshipIsValidEmail())
        XCTAssertFalse("@domain.com".airshipIsValidEmail())
        XCTAssertFalse("user@".airshipIsValidEmail())
        XCTAssertFalse("user".airshipIsValidEmail())
        XCTAssertFalse("domain.com".airshipIsValidEmail())
        XCTAssertFalse("user@domain".airshipIsValidEmail())
        XCTAssertFalse("@domain".airshipIsValidEmail())
        XCTAssertFalse("user@@domain.com".airshipIsValidEmail())
        XCTAssertFalse("user@domain@test.com".airshipIsValidEmail())
    }

    func testEmailValidationWhitespaceHandling() {
        // These should be valid after trimming
        XCTAssertTrue(" user@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user@domain.com ".airshipIsValidEmail())

        // These should be invalid even after trimming
        XCTAssertFalse("user @domain.com".airshipIsValidEmail())
        XCTAssertFalse("user@ domain.com".airshipIsValidEmail())
        XCTAssertFalse("us er@domain.com".airshipIsValidEmail())
        XCTAssertFalse("user@do main.com".airshipIsValidEmail())
    }

    func testEmailValidationEdgeCases() {
        // Valid edge cases
        XCTAssertTrue("user.@domain.com".airshipIsValidEmail())
        XCTAssertTrue(".user@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user@.domain.com".airshipIsValidEmail())
        XCTAssertTrue("user@domain..com".airshipIsValidEmail())
        XCTAssertTrue("user..name@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user+name@domain.com".airshipIsValidEmail())
        XCTAssertTrue("user!#$%&'*+-/=?^_`{|}~@domain.com".airshipIsValidEmail())

        // Invalid edge cases
        XCTAssertFalse("user@domain.com.".airshipIsValidEmail())
        XCTAssertFalse("user@domain@example.com".airshipIsValidEmail())
    }
}
