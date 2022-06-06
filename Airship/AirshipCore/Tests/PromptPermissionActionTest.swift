/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class PromptPermissionActionTest: XCTestCase {

    let testPrompter = TestPermissionPrompter()
    var action: PromptPermissionAction!

    override func setUpWithError() throws {
        self.action = PromptPermissionAction {
            return self.testPrompter
        }
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
            let args = ActionArguments(value: "anything", with: situation)
            XCTAssertTrue(self.action.acceptsArguments(args))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: "anything", with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }

    func testPrompt() throws {
        let actionValue: [String: Any] = [
            "permission": Permission.location.stringValue,
            "enable_airship_usage": true,
            "fallback_system_settings": true,
        ]

        let arguments = ActionArguments(value: actionValue, with: .manualInvocation)

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

    func testPromptDefaultArguments() throws {
        let actionValue = ["permission": Permission.postNotifications.stringValue]
        let arguments = ActionArguments(value: actionValue, with: .manualInvocation)

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = { permission, enableAirshipUsage, fallbackSystemSetting, completionHandler in
            XCTAssertEqual(permission, .postNotifications)
            XCTAssertFalse(enableAirshipUsage)
            XCTAssertFalse(fallbackSystemSetting)
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

    func testInvalidPermission() throws {
        let actionValue: [String: Any] = [
            "permission": "not a permission"
        ]

        let arguments = ActionArguments(value: actionValue, with: .manualInvocation)

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
        let actionValue: [String: Any] = [
            "permission": Permission.location.stringValue
        ]

        let resultReceived = self.expectation(description: "Result received")

        let resultRecevier: (Permission, PermissionStatus, PermissionStatus) -> Void = { permission, start, end in
            XCTAssertEqual(.notDetermined, start)
            XCTAssertEqual(.granted, end)
            XCTAssertEqual(.location, permission)
            resultReceived.fulfill()
        }

        let metadata = [PromptPermissionAction.resultReceiverMetadataKey: resultRecevier]

        let arguments = ActionArguments(value: actionValue,
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


