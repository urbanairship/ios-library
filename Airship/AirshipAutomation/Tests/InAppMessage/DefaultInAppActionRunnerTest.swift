/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipAutomation

final class DefaultInAppActionRunnerTest: XCTestCase {

    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()

    @MainActor
    func testCustomEventContext() {
        let layoutContext = ThomasLayoutContext(
            formInfo: nil,
            pagerInfo: nil,
            buttonInfo: ThomasButtonInfo(identifier: "bar")
        )

        let customEventContext = InAppCustomEventContext(
            id: InAppEventMessageID.appDefined(identifier: "foo"),
            context: InAppEventContext()
        )

        analytics.onMakeCustomEventContext = { lc in
            XCTAssertEqual(layoutContext, lc)
            return customEventContext
        }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: layoutContext)

        XCTAssertEqual(customEventContext, metadata[AddCustomEventAction._inAppMetadata] as? InAppCustomEventContext)
    }

    @MainActor
    func testCustomEventContextNilLayoutContext() {
        let customEventContext = InAppCustomEventContext(
            id: InAppEventMessageID.appDefined(identifier: "foo"),
            context: InAppEventContext()
        )

        analytics.onMakeCustomEventContext = { lc in
            XCTAssertNil(lc)
            return customEventContext
        }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        XCTAssertEqual(customEventContext, metadata[AddCustomEventAction._inAppMetadata] as? InAppCustomEventContext)
    }

    @MainActor
    func testTrackPermissionResults() async {
        let layoutContext = ThomasLayoutContext(
            formInfo: nil,
            pagerInfo: nil,
            buttonInfo: ThomasButtonInfo(identifier: "bar")
        )

        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: layoutContext)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as! PermissionResultReceiver
        await resultReceiver(.displayNotifications, .granted, .granted)

        verifyEvents(
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

    @MainActor
    func testTrackPermissionResultsNoContext() async {
        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: true)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as! PermissionResultReceiver
        await resultReceiver(.displayNotifications, .granted, .granted)

        verifyEvents(
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

    @MainActor
    func testTrackPermissionRusultsDisabled() async {
        analytics.onMakeCustomEventContext = { _ in return nil }

        let runner = DefaultInAppActionRunner(analytics: analytics, trackPermissionResults: false)
        var metadata: [String: Sendable] = [:]
        runner.extendMetadata(&metadata, layoutContext: nil)

        let resultReceiver = metadata[PromptPermissionAction.resultReceiverMetadataKey] as? PermissionResultReceiver
        XCTAssertNil(resultReceiver)
    }

    private func verifyEvents(_ expected: [(InAppEvent, ThomasLayoutContext?)], line: UInt = #line) {
           XCTAssertEqual(expected.count, self.analytics.events.count, line: line)

           expected.indices.forEach { index in
               let expectedEvent = expected[index]
               let actual = analytics.events[index]
               XCTAssertEqual(actual.0.name, expectedEvent.0.name, line: line)
               XCTAssertEqual(try! AirshipJSON.wrap(actual.0.data), try! AirshipJSON.wrap(expectedEvent.0.data), line: line)
               XCTAssertEqual(actual.1, expectedEvent.1, line: line)
           }
       }

}
