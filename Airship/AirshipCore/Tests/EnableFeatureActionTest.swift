/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class EnableFeatureActionTest: XCTestCase {

    let testPrompter = TestPermissionPrompter()
    var action: EnableFeatureAction!

    override func setUpWithError() throws {
        self.action = EnableFeatureAction { return self.testPrompter }
    }

    func testAcceptsArguments() async throws {
        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush,
        ]

        let rejectedSituations = [
            ActionSituation.backgroundPush,
            ActionSituation.backgroundInteractiveButton,
        ]


        for situation in validSituations {
            let args = ActionArguments(
                string: EnableFeatureAction.locationActionValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(
                string: EnableFeatureAction.locationActionValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testLocation() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.locationActionValue,
            situation: .manualInvocation
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

      
        let result = try await self.action.perform(arguments: arguments)
        await self.fulfillmentCompat(of: [prompted], timeout: 10)
    }

    func testBackgroundLocation() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.backgroundLocationActionValue,
            situation: .manualInvocation
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

        let result = try await self.action.perform(arguments: arguments)
        await self.fulfillmentCompat(of: [prompted], timeout: 10)
    }

    func testNotifications() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.userNotificationsActionValue,
            situation: .manualInvocation
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

        let result = try await self.action.perform(arguments: arguments)
        await self.fulfillmentCompat(of: [prompted], timeout: 10)
    }

    func testInvalidArgument() async throws {
        let arguments = ActionArguments(
            string: "invalid",
            situation: .manualInvocation
        )

        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            XCTFail()
            return (.notDetermined, .notDetermined)
        }

        do {
            _ = try await self.action.perform(arguments: arguments)
            XCTFail("should throw")
        } catch {}
    }

    func testResultReceiver() async throws {
        let resultReceived = self.expectation(description: "Result received")

        let resultRecevier:
         @Sendable (AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus) -> Void = {
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
            string: EnableFeatureAction.locationActionValue,
            situation: .manualInvocation,
            metadata: metadata
        )
        
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            return (.notDetermined, .granted)
        }
      
        _ = try await self.action.perform(arguments: arguments)
        await self.fulfillmentCompat(of: [resultReceived], timeout: 10)
    }
}
