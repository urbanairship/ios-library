/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@MainActor
@Suite
struct DeepLinkActionTest {

    private let testURLOpener: TestURLOpener = TestURLOpener()
    private let urlAllowList: TestURLAllowList = TestURLAllowList()
    private let airship: TestAirshipInstance
    private let action: DeepLinkAction

    init() {
        self.airship = TestAirshipInstance()
        self.action = DeepLinkAction(urlOpener: self.testURLOpener)
        self.airship.urlAllowList = self.urlAllowList
        self.airship.makeShared()
    }

    @Test
    func testAcceptsArguments() async throws {
        defer { TestAirshipInstance.clearShared() }

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
            ActionSituation.backgroundInteractiveButton
        ]

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testPerformDeepLinkDelegate() async throws {
        defer { TestAirshipInstance.clearShared() }

        let deepLinkDelegate = TestDeepLinkDelegate()
        self.urlAllowList.isAllowedReturnValue = false
        self.testURLOpener.returnValue = false

        self.airship.deepLinkDelegate = deepLinkDelegate

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        _ = try await action.perform(arguments: args)

        #expect("http://some-valid-url" == deepLinkDelegate.lastDeepLink?.absoluteString)
        #expect(self.testURLOpener.lastURL == nil)
    }

    @Test
    func testPerformFallback() async throws {
        defer { TestAirshipInstance.clearShared() }

        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        _ = try await action.perform(arguments: args)
        #expect("http://some-valid-url" == self.testURLOpener.lastURL?.absoluteString)
    }

    @Test
    func testPerformFallbackRejectsURL() async throws {
        defer { TestAirshipInstance.clearShared() }

        self.urlAllowList.isAllowedReturnValue = false
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            Issue.record("Should throw")
        } catch {}

        #expect(self.testURLOpener.lastURL == nil)
    }

    @Test
    func testPerformFallbackUnableToOpenURL() async throws {
        defer { TestAirshipInstance.clearShared() }

        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = false

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            Issue.record("Should throw")
        } catch {}

        #expect("http://some-valid-url" == self.testURLOpener.lastURL?.absoluteString)
    }

    @Test
    func testPerformInvalidURL() async throws {
        defer { TestAirshipInstance.clearShared() }

        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            double: 10.0,
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            Issue.record("Should throw")
        } catch {}

        #expect(self.testURLOpener.lastURL == nil)
    }
}


fileprivate final class TestDeepLinkDelegate: DeepLinkDelegate, @unchecked Sendable {
    var lastDeepLink: URL?
    func receivedDeepLink(_ deepLink: URL) async {
        self.lastDeepLink = deepLink
    }
}
