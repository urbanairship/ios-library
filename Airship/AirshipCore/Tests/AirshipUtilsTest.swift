/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore
import Foundation

@Suite struct AirshipUtilsTest {

    @Test
    func testSignedToken() throws {

        #expect(
            "VWtkZq18HZM3GWzD/q27qPSVszysSyoQfQ6tDEAcAko=" ==
            (try! AirshipUtils.generateSignedToken(secret: "appSecret", tokenParams: ["appKey", "some channel"]))
        )

        #expect(
            "Npyqy5OZxMEVv4bt64S3aUE4NwUQVLX50vGrEegohFE=" ==
            (try! AirshipUtils.generateSignedToken(secret: "test-app-secret", tokenParams: ["test-app-key", "channel ID"]))
        )
    }

    @Test
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

        #expect(AirshipUtils.isSilentPush(emptyNotification))
        #expect(AirshipUtils.isSilentPush(emptyAlert))
        #expect(AirshipUtils.isSilentPush(emptyLocKey))
        #expect(AirshipUtils.isSilentPush(emptyBody))
    }

    @Test
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

        #expect(!(AirshipUtils.isSilentPush(alertNotification)))
        #expect(!(AirshipUtils.isSilentPush(badgeNotification)))
        #expect(!(AirshipUtils.isSilentPush(soundNotification)))
        #expect(!(AirshipUtils.isSilentPush(notification)))
        #expect(!(AirshipUtils.isSilentPush(locKeyNotification)))
        #expect(!(AirshipUtils.isSilentPush(bodyNotification)))
    }

    @Test
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

        #expect(AirshipUtils.isAlertingPush(alertNotification))
        #expect(AirshipUtils.isAlertingPush(notification))
        #expect(AirshipUtils.isAlertingPush(locKeyNotification))
        #expect(AirshipUtils.isAlertingPush(bodyNotification))
    }

    @Test
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

        #expect(!(AirshipUtils.isAlertingPush(emptyNotification)))
        #expect(!(AirshipUtils.isAlertingPush(emptyAlert)))
        #expect(!(AirshipUtils.isAlertingPush(emptyLocKey)))
        #expect(!(AirshipUtils.isAlertingPush(emptyBody)))
        #expect(!(AirshipUtils.isAlertingPush(badgeNotification)))
        #expect(!(AirshipUtils.isAlertingPush(soundNotification)))
    }

    @Test
    func testParseURL() {
        var originalUrl = "https://advswift.com/api/v1?page=url+components"
        var url = AirshipUtils.parseURL(originalUrl)
        #expect(url != nil)
        #expect(originalUrl == url?.absoluteString)

        originalUrl = "rtlmost://szakaszó.com/main/típus/v1?page=azonosító"
        url = AirshipUtils.parseURL(originalUrl)
        #expect(url != nil)

        if #available(iOS 17.0, tvOS 17.0, *) {
            let encodedUrl = "rtlmost://xn--szakasz-r0a.com/main/t%C3%ADpus/v1?page=azonos%C3%ADt%C3%B3"
            #expect(encodedUrl == url?.absoluteString)
        } else {
            let encodedUrl = "rtlmost://szakasz%C3%B3.com/main/t%C3%ADpus/v1?page=azonos%C3%ADt%C3%B3"
            #expect(encodedUrl == url?.absoluteString)
        }
    }
}
