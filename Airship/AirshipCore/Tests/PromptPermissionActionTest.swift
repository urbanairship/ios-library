/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PromptPermissionActionTest {

    let testPrompter = TestPermissionPrompter()
    let action: PromptPermissionAction

    init() {
        let testPrompter = self.testPrompter
        self.action = PromptPermissionAction {
            return testPrompter
        }
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
            let args = ActionArguments(value: AirshipJSON.string("anything"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: AirshipJSON.string("anything"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testPrompt() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.rawValue,
            "enable_airship_usage": true,
            "fallback_system_settings": true,
        ]

        let arguments = ActionArguments(
            value: try! AirshipJSON.wrap(actionValue)
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


        let result = try await self.action.perform(arguments: arguments)
        #expect(result == nil)
        await fulfillment(of: [prompted], timeout: 10)
    }

    @Test
    func testPromptDefaultArguments() async throws {
        let actionValue = [
            "permission": AirshipPermission.displayNotifications.rawValue
        ]
        let arguments = ActionArguments(
            value: try! AirshipJSON.wrap(actionValue),
            situation: .manualInvocation
        )

        let prompted = AirshipTestExpectation(description: "Prompted")
        testPrompter.onPrompt = {
            permission,
            enableAirshipUsage,
            fallbackSystemSetting in
            #expect(permission == .displayNotifications)
            #expect(!(enableAirshipUsage))
            #expect(!(fallbackSystemSetting))
            prompted.fulfill()
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }


        let result = try await self.action.perform(arguments: arguments)
        #expect(result == nil)
        await fulfillment(of: [prompted], timeout: 10)
    }

    @Test
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
            Issue.record("Should not be prompted")
            return AirshipPermissionResult(startStatus: .notDetermined, endStatus: .notDetermined)
        }

        do {
            _ = try await self.action.perform(arguments: arguments)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testResultReceiver() async throws {
        let actionValue: [String: Any] = [
            "permission": AirshipPermission.location.rawValue
        ]

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
            value: try! AirshipJSON.wrap(actionValue),
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
