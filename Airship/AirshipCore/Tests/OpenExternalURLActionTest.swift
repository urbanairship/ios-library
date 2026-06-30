/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@MainActor
@Suite
struct OpenExternalURLActionTest {

    private let testURLOpener: TestURLOpener = TestURLOpener()
    private let urlAllowList: TestURLAllowList = TestURLAllowList()
    private let airship: TestAirshipInstance
    private let action: OpenExternalURLAction

    init() {
        self.airship = TestAirshipInstance()
        self.action = OpenExternalURLAction(urlOpener: self.testURLOpener)
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
    func testPerform() async throws {
        defer { TestAirshipInstance.clearShared() }

        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        let result = try await action.perform(arguments: args)
        #expect(args.value == result)
        #expect("http://some-valid-url" == self.testURLOpener.lastURL?.absoluteString)
    }

    @Test
    func testPerformRejectsURL() async throws {
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
    func testPerformUnableToOpenURL() async throws {
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
