import XCTest

@testable import AirshipCore

class RateAppActionTest: XCTestCase {
    private let testAppRater = TestAppRater()
    private var configItunesID: String? = nil
    private var action: RateAppAction!

    override func setUpWithError() throws {
        self.action = RateAppAction(
            appRater: self.testAppRater
        ) {
            return self.configItunesID
        }
    }

    func testShowPrompt() async throws {
        let args: [String: Any] = [
            "show_link_prompt": true,
            "itunes_id": "test id",
        ]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        XCTAssertNil(result)
        XCTAssertTrue(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testOpenAppStore() async throws {
        let args: [String: Any] = [
            "itunes_id": "test id"
        ]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        XCTAssertNil(result)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual("test id", testAppRater.openStoreItunesID)
    }

    func testOpenAppStoreFallbackItunesID() async throws {
        self.configItunesID = "config iTunes ID"
        let args: [String: Any] = [:]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        XCTAssertNil(result)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual(configItunesID, testAppRater.openStoreItunesID)
    }

    func testNilConfig() async throws {
        self.configItunesID = "config iTunes ID"

        let result = try await action.perform(arguments:
            ActionArguments(
                value: AirshipJSON.null,
                situation: .manualInvocation
            )
        )
        XCTAssertNil(result)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual(configItunesID, testAppRater.openStoreItunesID)
    }

    func testNoItunesID() async throws {
        self.configItunesID = nil

        do {
            _ = try await action.perform(arguments:
                ActionArguments(
                    value: AirshipJSON.null,
                    situation: .manualInvocation
                )
            )
            XCTFail("should throw")
        } catch {}

        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testInvalidArgs() async throws {
        self.configItunesID = "config id"
        do {
            _ = try await action.perform(arguments:
                ActionArguments(
                    string: "invalid"
                )
            )
            XCTFail("should throw")
        } catch {}
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testAcceptsArguments() async throws {
        let validSituations: [ActionSituation] = [
            .manualInvocation,
            .automation,
            .foregroundPush,
            .foregroundInteractiveButton,
            .webViewInvocation,
            .launchedFromPush,
        ]

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }
    }

    func testRejectsArguments() async throws {
        let invalidSituations: [ActionSituation] = [
            .backgroundPush,
            .backgroundInteractiveButton,
        ]

        for situation in invalidSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }


    fileprivate class TestAppRater: AppRaterProtocol, @unchecked Sendable {
        var showPromptCalled = false
        var openStoreItunesID: String? = nil

        func openStore(itunesID: String) async throws {
            openStoreItunesID = itunesID
        }

        func showPrompt() throws {
            showPromptCalled = true
        }
    }
}
