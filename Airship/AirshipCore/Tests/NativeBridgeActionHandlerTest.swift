/* Copyright Airship and Contributors */

import XCTest
@testable
public import AirshipCore

import WebKit

final class NativeBridgeActionHandlerTest: XCTestCase {

    private let metadata: [String: String] = ["some": UUID().uuidString]

    private let testActionRunner = TestActionRunner()

    private let webView = WKWebView()
    private var actionHandler: NativeBridgeActionHandler!
    override func setUpWithError() throws {
        self.actionHandler = NativeBridgeActionHandler(actionRunner: testActionRunner)
    }

    func testRunActionsMultiple() async throws {
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-actions?test%2520action=%22hi%22&also_test_action"
            )!
        )


        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        XCTAssertNil(result)

        let expecteActions: [String: [ActionArguments]] = [
            "test%20action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)],
            "also_test_action": [ActionArguments(situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }


    func testRunActionsMultipleArgs() async throws {
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-actions?test_action&test_action"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        XCTAssertNil(result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [
                ActionArguments(situation: .webViewInvocation, metadata: metadata),
                ActionArguments(situation: .webViewInvocation, metadata: metadata)
            ]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunActionsInvalidArgs() async throws {
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-actions?test_action=blah"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        XCTAssertNil(result)

        XCTAssertEqual([:], self.testActionRunner.ranActions)
    }

    func testRunActionCBNullResult() async throws {
        self.testActionRunner.actionResult = .completed(AirshipJSON.null)
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-action-cb/test_action/%22hi%22/callback-ID-1"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        let expectedResult = "UAirship.finishAction(null, null, \"callback-ID-1\");"
        XCTAssertEqual(expectedResult, result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunActionCBValueResult() async throws {
        self.testActionRunner.actionResult = .completed(AirshipJSON.string("neat"))
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-action-cb/test_action/%22hi%22/callback-ID-2"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        let expectedResult = "UAirship.finishAction(null, \"neat\", \"callback-ID-2\");"
        XCTAssertEqual(expectedResult, result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunActionCBError() async throws {
        self.testActionRunner.actionResult = .error(AirshipErrors.error("Some error"))
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-action-cb/test_action/%22hi%22/callback-ID-2"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        let expectedResult = "var error = new Error(); error.message = \"Some error\"; UAirship.finishAction(error, null, \"callback-ID-2\");"
        XCTAssertEqual(expectedResult, result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunActionCBActionNotFound() async throws {
        self.testActionRunner.actionResult = .actionNotFound
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-action-cb/test_action/%22hi%22/callback-ID-2"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        let expectedResult = "var error = new Error(); error.message = \"No action found with name test_action, skipping action.\"; UAirship.finishAction(error, null, \"callback-ID-2\");"
        XCTAssertEqual(expectedResult, result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunActionCBActionArgsRejected() async throws {
        self.testActionRunner.actionResult = .argumentsRejected
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-action-cb/test_action/%22hi%22/callback-ID-2"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        let expectedResult = "var error = new Error(); error.message = \"Action test_action rejected arguments.\"; UAirship.finishAction(error, null, \"callback-ID-2\");"
        XCTAssertEqual(expectedResult, result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunBasicActions() async throws {
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-basic-actions?test_action=hi&also_test_action"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        XCTAssertNil(result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [ActionArguments(string: "hi", situation: .webViewInvocation, metadata: metadata)],
            "also_test_action": [ActionArguments(situation: .webViewInvocation, metadata: metadata)]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }

    func testRunBasicActionsMultipleArgs() async throws {
        let command = JavaScriptCommand(
            url: URL(
                string: "uairship://run-basic-actions?test_action&test_action"
            )!
        )

        let result = await self.actionHandler.runActionsForCommand(command: command, metadata: metadata, webView: self.webView)
        XCTAssertNil(result)

        let expecteActions: [String: [ActionArguments]] = [
            "test_action": [
                ActionArguments(situation: .webViewInvocation, metadata: metadata),
                ActionArguments(situation: .webViewInvocation, metadata: metadata)
            ]
        ]

        XCTAssertEqual(expecteActions, self.testActionRunner.ranActions)
    }
}


final class TestActionRunner: NativeBridgeActionRunner {
    var actionResult: ActionResult = .completed(AirshipJSON.null)
    var ranActions: [String: [ActionArguments]] = [:]

    @MainActor
    func runAction(actionName: String, arguments: AirshipCore.ActionArguments, webView: WKWebView) async -> AirshipCore.ActionResult {
        ranActions[actionName] = ranActions[actionName] ?? []
        ranActions[actionName]?.append(arguments)
        return actionResult
    }
}

extension ActionArguments: @retroactive Equatable {
    public static func == (lhs: AirshipCore.ActionArguments, rhs: AirshipCore.ActionArguments) -> Bool {
        lhs.value == rhs.value && lhs.situation == rhs.situation && NSDictionary(dictionary: lhs.metadata) == NSDictionary(dictionary: rhs.metadata)
    }

}
