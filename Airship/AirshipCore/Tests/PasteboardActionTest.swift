/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class PasteboardActionTest: XCTestCase {

    private var action: PasteboardAction!

    override func setUp() async throws {
        action = PasteboardAction()
    }

    func testAcceptsArguments() throws {
        let validStringValue = "pasteboard string"

        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation,
            Situation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            Situation.foregroundPush,
            Situation.backgroundPush
        ]

        validSituations.forEach { (situation) in
            let validArgs = ActionArguments(
                value: validStringValue,
                with: situation
            )
            XCTAssertTrue(self.action.acceptsArguments(validArgs))

            let invalidArgs = ActionArguments(
                value: [[:]],
                with: situation
            )
            XCTAssertFalse(self.action.acceptsArguments(invalidArgs))

        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: validStringValue, with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
        
        let validDictValue = ["text": "pasteboard string"]
        
        validSituations.forEach { (situation) in
            let validArgs = ActionArguments(
                value: validDictValue,
                with: situation
            )
            XCTAssertTrue(self.action.acceptsArguments(validArgs))
        }

        rejectedSituations.forEach { (situation) in
            let args = ActionArguments(value: validDictValue, with: situation)
            XCTAssertFalse(self.action.acceptsArguments(args))
        }
    }
    
    func testPerformWithString() async throws {
        let arguments = ActionArguments(value: "pasteboard_string", with: .manualInvocation)
      
        let result = await self.action.perform(
            with: arguments
        )
        
       XCTAssertEqual(result.value as! String, arguments.value as! String)
        
    }
    
    func testPerformWithDictionary() async throws {
        let arguments = ActionArguments(value: ["text": "pasteboard string"], with: .manualInvocation)
        
        let result = await self.action.perform(
            with: arguments
        )
        
        XCTAssertEqual(result.value as! [String : String], arguments.value as! [String : String])
    }
}
