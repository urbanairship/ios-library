/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class EnableFeatureActionTest: XCTestCase {

    let testPrompter = TestPermissionPrompter()
    var action: EnableFeatureAction!

    override func setUpWithError() throws {
        self.action = EnableFeatureAction { return self.testPrompter }
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
            let args = ActionArguments(
                value: EnableFeatureAction.locationActionValue,
                with: situation
            )
            XCTAssertTrue(self.action.acceptsArguments(args))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(
                value: EnableFeatureAction.locationActionValue,
                with: situation
            )
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }

    func testLocation() async throws {
        let arguments = ActionArguments(
            value: EnableFeatureAction.locationActionValue,
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

    func testBackgroundLocation() async throws {
        let arguments = ActionArguments(
            value: EnableFeatureAction.backgroundLocationActionValue,
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

    func testNotifications() async throws {
        let arguments = ActionArguments(
            value: EnableFeatureAction.userNotificationsActionValue,
            with: .manualInvocation
        )

        let prompted = self.expectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            XCTAssertEqual(permission, .displayNotifications)
            XCTAssertTrue(enableAirshipUsage)
            XCTAssertTrue(fallbackSystemSetting)
            prompted.fulfill()
            return (.notDetermined, .notDetermined)
        }

        let result = await self.action.perform(with: arguments)
        XCTAssertNil(result.value)
        await self.waitForExpectations(timeout: 10)
    }

    func testInvalidArgument() async throws {
        let arguments = ActionArguments(
            value: "invalid",
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
            value: EnableFeatureAction.locationActionValue,
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
