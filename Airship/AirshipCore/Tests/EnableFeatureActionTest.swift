/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class EnableFeatureActionTest: XCTestCase {

    let testPrompter = TestPermissionPrompter()
    var action: EnableFeatureAction!

    override func setUpWithError() throws {
        self.action = EnableFeatureAction {  return self.testPrompter }
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation,
            Situation.foregroundPush
        ]

        let rejectedSituations = [
            Situation.backgroundPush,
            Situation.backgroundInteractiveButton
        ]

        validSituations.forEach { (situation) in
            let args = ActionArguments(value: EnableFeatureAction.locationActionValue, with: situation)
            XCTAssertTrue(self.action.acceptsArguments(args))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: EnableFeatureAction.locationActionValue, with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }

    func testLocation() throws {
        let arguments = ActionArguments(value: EnableFeatureAction.locationActionValue,
                                        with: .manualInvocation)

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            XCTAssertEqual(permission, .location)
            XCTAssertTrue(enableAirshipUsage)
            XCTAssertTrue(fallbackSystemSetting)
            completionHandler(.notDetermined, .notDetermined)
            prompted.fulfill()
        }

        let actionFinished = self.expectation(description: "Action finished")
        self.action.perform(with: arguments) { result in
            XCTAssertNil(result.value)
            actionFinished.fulfill()
        }

        self.wait(for: [actionFinished, prompted], timeout: 1)
    }

    func testBackgroundLocation() throws {
        let arguments = ActionArguments(value: EnableFeatureAction.backgroundLocationActionValue,
                                        with: .manualInvocation)

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            XCTAssertEqual(permission, .location)
            XCTAssertTrue(enableAirshipUsage)
            XCTAssertTrue(fallbackSystemSetting)
            completionHandler(.notDetermined, .notDetermined)
            prompted.fulfill()
        }

        let actionFinished = self.expectation(description: "Action finished")
        self.action.perform(with: arguments) { result in
            XCTAssertNil(result.value)
            actionFinished.fulfill()
        }

        self.wait(for: [actionFinished, prompted], timeout: 1)
    }


    func testNotifications() throws {
        let arguments = ActionArguments(value: EnableFeatureAction.userNotificationsActionValue,
                                        with: .manualInvocation)

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            XCTAssertEqual(permission, .displayNotifications)
            XCTAssertTrue(enableAirshipUsage)
            XCTAssertTrue(fallbackSystemSetting)
            completionHandler(.notDetermined, .notDetermined)
            prompted.fulfill()
        }

        let actionFinished = self.expectation(description: "Action finished")
        self.action.perform(with: arguments) { result in
            XCTAssertNil(result.value)
            actionFinished.fulfill()
        }

        self.wait(for: [actionFinished, prompted], timeout: 1)
    }


    func testInvalidArgument() throws {
        let arguments = ActionArguments(value: "invalid", with: .manualInvocation)

        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            XCTFail()
        }

        let actionFinished = self.expectation(description: "Action finished")
        self.action.perform(with: arguments) { result in
            XCTAssertNotNil(result.error)
            actionFinished.fulfill()
        }

        self.wait(for: [actionFinished], timeout: 1)
    }

    func testResultReceiver() throws {
        let resultReceived = self.expectation(description: "Result received")

        let resultRecevier: (Permission, PermissionStatus, PermissionStatus) -> Void = { permission, start, end in
            XCTAssertEqual(.notDetermined, start)
            XCTAssertEqual(.granted, end)
            XCTAssertEqual(.location, permission)
            resultReceived.fulfill()
        }

        let metadata = [PromptPermissionAction.resultReceiverMetadataKey: resultRecevier]

        let arguments = ActionArguments(value: EnableFeatureAction.locationActionValue,
                                        with: .manualInvocation,
                                        metadata: metadata)

        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            completionHandler(.notDetermined, .granted)
        }

        let actionFinished = self.expectation(description: "Action finished")
        self.action.perform(with: arguments) { _ in
            actionFinished.fulfill()
        }

        self.wait(for: [actionFinished, resultReceived], timeout: 1)
    }
}

