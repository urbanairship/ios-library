/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class PasteboardActionTest: XCTestCase {

    private var action: PasteboardAction!

    override func setUp() async throws {
        action = PasteboardAction()
    }

    func testAcceptsArguments() async throws {
        let validStringValue = "pasteboard string"
        let validDictValue = ["text": "pasteboard string"]

        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            ActionSituation.foregroundPush,
            ActionSituation.backgroundPush
        ]

        for situation in validSituations {
            let args = ActionArguments(
                string: validStringValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in validSituations {
            let args = ActionArguments(
                value: try AirshipJSON.wrap(validDictValue),
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in validSituations {
            let args = ActionArguments(
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(
                string: validStringValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }
    
    func testPerformWithString() async throws {
        let arguments = ActionArguments(string: "pasteboard_string")
        let result = try await self.action.perform(arguments: arguments)
        XCTAssertEqual(result, arguments.value)
    }
    
    func testPerformWithDictionary() async throws {
        let arguments = ActionArguments(value: try AirshipJSON.wrap(["text": "pasteboard string"]))
        let result = try await self.action.perform(arguments: arguments)
        XCTAssertEqual(result, arguments.value)
    }
}
