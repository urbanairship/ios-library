/* Copyright 2010-2019 Urban Airship and Contributors */

import XCTest
import KIF
import AirshipKit

// Tester is defined as a preprocessor macro in obj-c and requires these extensions in swift
extension XCTestCase {
    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }
}
extension KIFTestActor {
    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }
}

/**
 * Functional tests to test push notification receipt.
 *
 * Note:
 * - These tests must be run on a device.
 * - These tests require a valid master secret to be included in the AirshipConfig.plist.
 * - This class can only reliably test content-available pushes because responding to the
 * push authorization prompt is currently not possible.
 *
 * Currently testing the following:
 * - Content-available push to channel
 * - Content-available push to tag
 */
class PushTests: KIFTestCase {

    static var pushClient:PushClient = PushClient()
    static var registrationDelegate:RegistrationDelegate = RegistrationDelegate()
    static var pushHandler:PushHandler = PushHandler()

    static var testTag:String = UUID().uuidString

    override func beforeAll() {
        super.beforeAll()

        // Set the forward delegate to whatever was previously set
        PushTests.registrationDelegate.forwardDelegate = UAirship.push().registrationDelegate

        UAirship.push().registrationDelegate = PushTests.registrationDelegate
        UAirship.push().pushNotificationDelegate = PushTests.pushHandler

        let expectation:XCTestExpectation = self.expectation(description: "Channel Registered")
        expectation.assertForOverFulfill = false

        // Set test tag
        UAirship.push().addTag(PushTests.testTag)
        UAirship.push().updateRegistration()

        // Wait for channel registration to return successfully
        PushTests.registrationDelegate.registrationSucceeded = { channelID, deviceToken in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 30, handler: nil)

        // Wait a little extra for tag to process in UA's backend, no great way of doing this
        sleep(10)
    }

    override func afterAll() {
        super.afterAll()

        // Clean up test tag
        UAirship.push().removeTag(PushTests.testTag)
        UAirship.push().updateRegistration()
    }

    // Tests content-available push to channel ID.
    func testPushChannelID() {
        let expectation:XCTestExpectation = self.expectation(description: "Push Received")

        PushTests.pushHandler.onReceivedForegroundNotification = { notificationContent in
            expectation.fulfill()
        }

        PushTests.pushClient.pushPayload(payload: { () -> ([String : Any]?) in
            var payload:Dictionary<String, Any> = [:]
            var platform:Dictionary<String, Any> = [:]
            var notification:Dictionary<String, Any> = [:]

            payload["audience"] = ["ios_channel" : UAirship.push().channelID!]
            payload["device_types"] = ["ios"]
            platform["content-available"] = true
            notification["ios"] = platform
            payload["notification"] = notification

            return payload
        })

        waitForExpectations(timeout: 30, handler: nil)
    }

    // Tests content-available push to tag.
    func testTagPush() {
        let expectation:XCTestExpectation = self.expectation(description: "Push Received")

        PushTests.pushHandler.onReceivedForegroundNotification = { notificationContent in
            expectation.fulfill()
        }

        PushTests.pushClient.pushPayload(payload: { () -> ([String : Any]?) in
            var payload:Dictionary<String, Any> = [:]
            var platform:Dictionary<String, Any> = [:]
            var notification:Dictionary<String, Any> = [:]

            payload["audience"] = ["tag": PushTests.testTag]
            payload["device_types"] = ["ios"]
            platform["content-available"] = true
            notification["ios"] = platform
            payload["notification"] = notification

            return payload
        })

        waitForExpectations(timeout: 30, handler: nil)
    }
}

