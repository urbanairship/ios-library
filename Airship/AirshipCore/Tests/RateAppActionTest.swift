import XCTest

@testable
import AirshipCore

class RateAppActionTest: XCTestCase {
    private let testAppRater = TestAppRater()
    private var configItunesID: String? = nil
    private var action: RateAppAction!

    override func setUpWithError() throws {
        self.action = RateAppAction(appRater: self.testAppRater) {
            return self.configItunesID
        }
    }

    func testShowPrompt() async throws {
        let args: [String: Any] = [
            "show_link_prompt": true,
            "itunes_id": "test id"
        ]

        let result = await action.perform(with: ActionArguments(value: args,
                                                                with: .manualInvocation))
        XCTAssertNil(result.error)
        XCTAssertTrue(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testOpenAppStore() async throws {
        let args: [String: Any] = [
            "itunes_id": "test id"
        ]

        let result = await action.perform(with: ActionArguments(value: args,
                                                                with: .manualInvocation))
        XCTAssertNil(result.error)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual("test id", testAppRater.openStoreItunesID)
    }

    func testOpenAppStoreFallbackItunesID() async throws {
        self.configItunesID = "config iTunes ID"
        let args: [String: Any] = [:]

        let result = await action.perform(with: ActionArguments(value: args,
                                                                with: .manualInvocation))
        XCTAssertNil(result.error)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual(configItunesID, testAppRater.openStoreItunesID)
    }

    func testNilConfig() async throws {
        self.configItunesID = "config iTunes ID"

        let result = await action.perform(with: ActionArguments(value: nil,
                                                                with: .manualInvocation))
        XCTAssertNil(result.error)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertEqual(configItunesID, testAppRater.openStoreItunesID)
    }

    func testNoItunesID() async throws {
        self.configItunesID = nil
        let result = await action.perform(with: ActionArguments(value: nil,
                                                                with: .manualInvocation))
        XCTAssertNotNil(result.error)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testInvalidArgs() async throws {
        self.configItunesID = "config id"
        let result = await action.perform(with: ActionArguments(value: "invalid",
                                                                with: .manualInvocation))
        XCTAssertNotNil(result.error)
        XCTAssertFalse(testAppRater.showPromptCalled)
        XCTAssertNil(testAppRater.openStoreItunesID)
    }

    func testAcceptsArguments() async throws {
        let validSituations: [Situation] = [
            .manualInvocation,
            .automation,
            .foregroundPush,
            .foregroundInteractiveButton,
            .webViewInvocation,
            .launchedFromPush
        ]

        validSituations.forEach {
            let args = ActionArguments(value: nil, with: $0)
            XCTAssertTrue(action.acceptsArguments(args))
        }
    }

    func testRejectsArguments() async throws {
        let invalidSituations: [Situation] = [
            .backgroundPush,
            .backgroundInteractiveButton
        ]

        invalidSituations.forEach {
            let args = ActionArguments(value: nil, with: $0)
            XCTAssertFalse(action.acceptsArguments(args))
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    fileprivate class TestAppRater: AppRaterProtocol {
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
