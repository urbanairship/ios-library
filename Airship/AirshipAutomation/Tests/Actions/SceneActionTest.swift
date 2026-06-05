/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable
import AirshipAutomation
@testable
import AirshipCore

private let minimalLayoutJSON = """
    {
      "version": 1,
      "presentation": {
        "type": "embedded",
        "embedded_id": "home_banner",
        "default_placement": {
          "size": { "width": "50%", "height": "50%" }
        }
      },
      "view": { "type": "container", "items": [] }
    }
    """

@MainActor
@Suite("SceneAction")
struct SceneActionTests {

    let compressedSceneBase64: String

    init() async throws {
        compressedSceneBase64 = try Data(minimalLayoutJSON.utf8).rawDeflateBase64()
    }

    // MARK: - Metadata / accepts

    @Test("default action names")
    func defaultNames() {
        #expect(Set(SceneAction.defaultNames) == ["scene_action", "^sc"])
    }

    @Test("accepts expected action situations")
    func acceptsArguments() async {
        let action = SceneAction()

        let validSituations: [ActionSituation] = [
            .foregroundInteractiveButton,
            .launchedFromPush,
            .manualInvocation,
            .webViewInvocation,
            .automation,
            .foregroundPush,
        ]

        let rejectedSituations: [ActionSituation] = [
            .backgroundPush,
            .backgroundInteractiveButton,
        ]

        for situation in validSituations {
            let args = ActionArguments(value: .null, situation: situation)
            #expect(await action.accepts(arguments: args) == true)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: .null, situation: situation)
            #expect(await action.accepts(arguments: args) == false)
        }
    }

    // MARK: - Happy path

    @Test("perform schedules compressed scene")
    func performSchedulesCompressedScene() async throws {
        try await confirmation(expectedCount: 1) { confirm in
            let action = SceneAction(
                scheduler: { schedule in
                    guard case .inAppMessage(let message) = schedule.data else {
                        Issue.record("Expected inAppMessage schedule data")
                        return
                    }

                    #expect(message.name == "Scene Landing Page ")
                    #expect(message.isReportingEnabled == false)
                    #expect(message.displayBehavior == .immediate)

                    guard case .airshipLayoutIntermediate = message.displayContent else {
                        Issue.record("Expected airshipLayoutIntermediate display content")
                        return
                    }

                    await self.expectStandardSceneSchedule(schedule)
                    confirm()
                }
            )

            let result = try await action.perform(arguments: sceneArgs(compressedSceneBase64))
            #expect(result == nil)
        }
    }

    @Test("perform uses push metadata for message name, reporting, and schedule id")
    func performMessageIdFromPushMetadata() async throws {
        let pushMetadata = AirshipJSON.object(["_": .string("some-send-ID")])

        try await confirmation(expectedCount: 1) { confirm in
            let action = SceneAction(
                scheduler: { schedule in
                    guard case .inAppMessage(let message) = schedule.data else {
                        Issue.record("Expected inAppMessage schedule data")
                        return
                    }

                    #expect(message.name == "Scene Landing Page some-send-ID")
                    #expect(message.isReportingEnabled == true)
                    #expect(schedule.identifier == "some-send-ID")

                    await self.expectStandardSceneSchedule(schedule)
                    confirm()
                }
            )

            let args = ActionArguments(
                value: try AirshipJSON.from(json: #"{"dsl":"\#(compressedSceneBase64)"}"#),
                situation: .manualInvocation,
                metadata: [ActionArguments.pushPayloadJSONMetadataKey: pushMetadata]
            )

            let result = try await action.perform(arguments: args)
            #expect(result == nil)
        }
    }

    // MARK: - Error cases

    @Test("perform throws on invalid base64")
    func performInvalidBase64ReturnsError() async {
        let action = SceneAction(scheduler: { _ in Issue.record("scheduler must not run") })
        let args = ActionArguments(
            value: .string("@@@not-valid-base64@@@"),
            situation: .manualInvocation
        )
        await #expect(throws: (any Error).self) {
            try await action.perform(arguments: args)
        }
    }

    @Test("perform throws on invalid deflate bytes")
    func performInvalidDeflateReturnsError() async throws {
        let garbage = Data([0x00, 0x01, 0x02, 0x03]).base64EncodedString()
        let action = SceneAction(scheduler: { _ in Issue.record("scheduler must not run") })
        let args = try sceneArgs(garbage)
        await #expect(throws: (any Error).self) {
            try await action.perform(arguments: args)
        }
    }

    @Test("perform throws when decompressed bytes are not valid JSON")
    func performDecompressedNotJsonReturnsError() async throws {
        let notJSON = try Data("not json {{{".utf8).rawDeflateBase64()
        let action = SceneAction(scheduler: { _ in Issue.record("scheduler must not run") })
        await #expect(throws: (any Error).self) {
            try await action.perform(arguments: try self.sceneArgs(notJSON))
        }
    }

    @Test("perform throws when dsl field is missing from action args")
    func performMissingDslFieldReturnsError() async {
        let action = SceneAction(scheduler: { _ in Issue.record("scheduler must not run") })
        let args = ActionArguments(
            value: .object(["other": .string("x")]),
            situation: .manualInvocation
        )
        await #expect(throws: (any Error).self) {
            try await action.perform(arguments: args)
        }
    }

    // MARK: - Helpers
    private func expectStandardSceneSchedule(_ schedule: AutomationSchedule) {
        #expect(schedule.triggers.count == 1)
        #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
        #expect(schedule.triggers[0].goal == 1.0)
        #expect(schedule.bypassHoldoutGroups == true)
        #expect(schedule.productID == "scene_page")
        #expect(schedule.queue == "landing_page")
        #expect(schedule.priority == Int.min)
    }

    private func sceneArgs(_ sceneBase64: String) throws -> ActionArguments {
        ActionArguments(
            value: try AirshipJSON.from(json: #"{"dsl":"\#(sceneBase64)"}"#),
            situation: .manualInvocation
        )
    }
}

fileprivate extension Data {
    func rawDeflateBase64() throws -> String {
        guard #available(macOS 10.15, *) else { throw CocoaError(.featureUnsupported) }
        return try (self as NSData).compressed(using: .zlib).base64EncodedString()
    }
}
