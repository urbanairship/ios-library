/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct EnableFeatureActionTest {

    let testPrompter = TestPermissionPrompter()
    let action: EnableFeatureAction

    init() {
        let testPrompter = self.testPrompter
        self.action = EnableFeatureAction { return testPrompter }
    }

    @Test
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
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(
                string: EnableFeatureAction.locationActionValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testLocation() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.locationActionValue,
            situation: .manualInvocation
        )

        let prompted = AirshipTestExpectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            #expect(permission == .location)
            #expect(enableAirshipUsage)
            #expect(fallbackSystemSetting)
            prompted.fulfill()
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }


        _ = try await self.action.perform(arguments: arguments)
        await fulfillment(of: [prompted], timeout: 10)
    }

    @Test
    func testBackgroundLocation() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.backgroundLocationActionValue,
            situation: .manualInvocation
        )

        let prompted = AirshipTestExpectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            #expect(permission == .location)
            #expect(enableAirshipUsage)
            #expect(fallbackSystemSetting)
            prompted.fulfill()
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }

        _ = try await self.action.perform(arguments: arguments)
        await fulfillment(of: [prompted], timeout: 10)
    }

    @Test
    func testNotifications() async throws {
        let arguments = ActionArguments(
            string: EnableFeatureAction.userNotificationsActionValue,
            situation: .manualInvocation
        )

        let prompted = AirshipTestExpectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            #expect(permission == .displayNotifications)
            #expect(enableAirshipUsage)
            #expect(fallbackSystemSetting)
            prompted.fulfill()
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }

        _ = try await self.action.perform(arguments: arguments)
        await fulfillment(of: [prompted], timeout: 10)
    }

    @Test
    func testInvalidArgument() async throws {
        let arguments = ActionArguments(
            string: "invalid",
            situation: .manualInvocation
        )

        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            Issue.record()
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }

        do {
            _ = try await self.action.perform(arguments: arguments)
            Issue.record("should throw")
        } catch {}
    }

    @Test
    func testResultReceiver() async throws {
        let resultReceived = AirshipTestExpectation(description: "Result received")

        let resultRecevier:
         @Sendable (AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus) async -> Void = {
                permission,
                start,
                end in
                #expect(.notDetermined == start)
                #expect(.granted == end)
                #expect(.location == permission)
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
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .granted)
        }

        _ = try await self.action.perform(arguments: arguments)
        await fulfillment(of: [resultReceived], timeout: 10)
    }
}
