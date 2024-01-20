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
            let args = ActionArguments(value: AirshipJSON.string("anything"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: AirshipJSON.string("anything"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testPrompt() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.stringValue,
            "enable_airship_usage": true,
            "fallback_system_settings": true,
        ]

        let arguments = ActionArguments(
            value: try! AirshipJSON.wrap(actionValue)
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
        XCTAssertNil(result)
        await self.fulfillmentCompat(of: [prompted], timeout: 10)
    }

    func testPromptDefaultArguments() async throws {
        let actionValue = [
            "permission": AirshipPermission.displayNotifications.stringValue
        ]
        let arguments = ActionArguments(
            value: try! AirshipJSON.wrap(actionValue),
            situation: .manualInvocation
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


        let result = try await self.action.perform(arguments: arguments)
        XCTAssertNil(result)
        await self.fulfillmentCompat(of: [prompted], timeout: 10)
    }

    func testInvalidPermission() async throws {
        let actionValue: [String: Any] = [
            "permission": "not a permission"
        ]

        let arguments = ActionArguments(
            value: try! AirshipJSON.wrap(actionValue),
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
            XCTFail("Should throw")
        } catch {}
    }

    func testResultReceiver() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.stringValue
        ]

        let resultReceived = self.expectation(description: "Result received")

        let resultRecevier:
            @Sendable (AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus) async -> Void = {
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
            value: try! AirshipJSON.wrap(actionValue),
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
