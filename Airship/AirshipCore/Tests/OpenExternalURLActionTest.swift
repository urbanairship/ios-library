/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class OpenExternalURLActionTest: XCTestCase {

    private let testURLOpener: TestURLOpener = TestURLOpener()
    private let urlAllowList: TestURLAllowList = TestURLAllowList()
    private var airship: TestAirshipInstance!

    private var action: OpenExternalURLAction!

    @MainActor
    override func setUp() {
        airship = TestAirshipInstance()
        self.action = OpenExternalURLAction(urlOpener: self.testURLOpener)
        self.airship.urlAllowList = self.urlAllowList
        self.airship.makeShared()
    }

    override func tearDown() async throws {
        TestAirshipInstance.clearShared()
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
            ActionSituation.backgroundInteractiveButton
        ]

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testPerform() async throws {
        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        let result = try await action.perform(arguments: args)
        XCTAssertEqual(args.value, result)
        XCTAssertEqual("http://some-valid-url", self.testURLOpener.lastURL?.absoluteString)
    }

    func testPerformRejectsURL() async throws {
        self.urlAllowList.isAllowedReturnValue = false
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            XCTFail("Should throw")
        } catch {}

        XCTAssertNil(self.testURLOpener.lastURL)
    }

    func testPerformUnableToOpenURL() async throws {
        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = false

        let args = ActionArguments(
            string: "http://some-valid-url",
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            XCTFail("Should throw")
        } catch {}

        XCTAssertEqual("http://some-valid-url", self.testURLOpener.lastURL?.absoluteString)
    }

    func testPerformInvalidURL() async throws {
        self.urlAllowList.isAllowedReturnValue = true
        self.testURLOpener.returnValue = true

        let args = ActionArguments(
            double: 10.0,
            situation: .manualInvocation
        )

        do {
            _ = try await action.perform(arguments: args)
            XCTFail("Should throw")
        } catch {}

        XCTAssertNil(self.testURLOpener.lastURL)
    }
}



