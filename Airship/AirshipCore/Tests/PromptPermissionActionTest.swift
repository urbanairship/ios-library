/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

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
            Situation.foregroundPush,
        ]

        let rejectedSituations = [
            Situation.backgroundPush,
            Situation.backgroundInteractiveButton,
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

    func testPrompt() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.stringValue,
            "enable_airship_usage": true,
            "fallback_system_settings": true,
        ]

        let arguments = ActionArguments(
            value: actionValue,
            with: .manualInvocation
        )

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            XCTAssertEqual(permission, .location)
            XCTAssertTrue(enableAirshipUsage)
            XCTAssertTrue(fallbackSystemSetting)
            prompted.fulfill()
            return (.notDetermined, .notDetermined)
        }

    
        let result = await self.action.perform(with: arguments)
        XCTAssertNil(result.value)
        await self.waitForExpectations(timeout: 10)
    }

    func testPromptDefaultArguments() async throws {
        let actionValue = [
            "permission": AirshipPermission.displayNotifications.stringValue
        ]
        let arguments = ActionArguments(
            value: actionValue,
            with: .manualInvocation
        )

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            XCTAssertEqual(permission, .displayNotifications)
            XCTAssertFalse(enableAirshipUsage)
            XCTAssertFalse(fallbackSystemSetting)
            prompted.fulfill()
            return (.notDetermined, .notDetermined)
        }

      
        let result = await self.action.perform(with: arguments)
        XCTAssertNil(result.value)
        await self.waitForExpectations(timeout: 10)
    }

    func testInvalidPermission() async throws {
        let actionValue: [String: Any] = [
            "permission": "not a permission"
        ]

        let arguments = ActionArguments(
            value: actionValue,
            with: .manualInvocation
        )

        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            XCTFail()
            return (.notDetermined, .notDetermined)
        }

        let result = await self.action.perform(with: arguments)
        XCTAssertNotNil(result.error)
    }

    func testResultReceiver() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.stringValue
        ]

        let resultReceived = self.expectation(description: "Result received")

        let resultRecevier:
            (AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus) -> Void = {
                permission,
                start,
                end in
                XCTAssertEqual(.notDetermined, start)
                XCTAssertEqual(.granted, end)
                XCTAssertEqual(.location, permission)
                resultReceived.fulfill()
            }

        let metadata = [
            PromptPermissionAction.resultReceiverMetadataKey: resultRecevier
        ]

        let arguments = ActionArguments(
            value: actionValue,
            with: .manualInvocation,
            metadata: metadata
        )

        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            return (.notDetermined, .granted)
        }

        _ = await self.action.perform(with: arguments)
        await self.waitForExpectations(timeout: 10)
    }
}
