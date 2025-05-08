/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
@testable import AirshipAutomation

@MainActor
struct DefaultInAppActionRunnerTest {

    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()

    @Test
    func testCustomEventContext() {
        let layoutContext = ThomasLayoutContext(
            button: ThomasLayoutContext.Button(identifier: "bar")
        )

        let customEventContext = InAppCustomEventContext(
            id: InAppEventMessageID.appDefined(identifier: "foo"),
            context: InAppEventContext()
        )

        analytics.onMakeCustomEventContext = { lc in
            #expect(layoutContext == lc)
            return customEventContext
        }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: layoutContext)

        #expect(customEventContext == metadata[AddCustomEventAction._inAppMetadata] as? InAppCustomEventContext)
    }

    @Test
    func testCustomEventContextNilLayoutContext() {
        let customEventContext = InAppCustomEventContext(
            id: InAppEventMessageID.appDefined(identifier: "foo"),
            context: InAppEventContext()
        )

        analytics.onMakeCustomEventContext = { lc in
            #expect(lc == nil)
            return customEventContext
        }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        #expect(customEventContext == metadata[AddCustomEventAction._inAppMetadata] as? InAppCustomEventContext)
    }

    @Test
    func testTrackPermissionResults() async throws {
        let layoutContext = ThomasLayoutContext(
            button: ThomasLayoutContext.Button(identifier: "bar")
        )

        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: layoutContext)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as! PermissionResultReceiver
        await resultReceiver(.displayNotifications, .granted, .granted)

        try verifyEvents(
            [
                (
                    InAppPermissionResultEvent(
                        permission: .displayNotifications,
                        startingStatus: .granted,
                        endingStatus: .granted
                    ),
                    layoutContext
                )
            ]
        )
    }

    @Test
    func testTrackPermissionResultsNoContext() async throws {
        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as! PermissionResultReceiver
        await resultReceiver(.displayNotifications, .granted, .granted)

        try verifyEvents(
            [
                (
                    InAppPermissionResultEvent(
                        permission: .displayNotifications,
                        startingStatus: .granted,
                        endingStatus: .granted
                    ),
                    nil
                )
            ]
        )
    }

    @Test
    func testTrackPermissionRusultsDisabled() async {
        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: false)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as? PermissionResultReceiver
        #expect(resultReceiver == nil)
    }

    private func verifyEvents(
        _ expected: [(InAppEvent, ThomasLayoutContext?)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #expect(expected.count == self.analytics.events.count, sourceLocation: sourceLocation)

        try expected.indices.forEach { index in
            let expectedEvent = expected[index]
            let actual = analytics.events[index]
            #expect(actual.0.name == expectedEvent.0.name, sourceLocation: sourceLocation)
            let actualData = try AirshipJSON.wrap(actual.0.data)
            let expectedData = try AirshipJSON.wrap(expectedEvent.0.data)
            #expect(actualData == expectedData, sourceLocation: sourceLocation)
            #expect(actual.1 == expectedEvent.1, sourceLocation: sourceLocation)
        }
    }
}
