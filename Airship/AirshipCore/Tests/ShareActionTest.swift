/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ShareActionTest: XCTestCase {

    private let value = "some valid text"
    private let numericValue = 222
    private var action: ShareAction!
    private var arguments: ActionArguments!

    override func setUp() async throws {
        action = ShareAction()
        arguments = ActionArguments(value: value, with: .backgroundInteractiveButton)
    }

    func testAcceptsArguments() throws {
        let validSituations = [
            Situation.foregroundInteractiveButton,
            Situation.launchedFromPush,
            Situation.manualInvocation,
            Situation.webViewInvocation,
            Situation.automation,
            Situation.foregroundPush
        ]

        let rejectedSituations = [
            Situation.backgroundPush,
            Situation.backgroundInteractiveButton
        ]

        validSituations.forEach { (situation) in
            XCTAssertTrue(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: value,
                        with: situation
                    )
                )
            )
        }
        
        validSituations.forEach { (situation) in
            XCTAssertFalse(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: numericValue,
                        with: situation
                    )
                )
            )
        }

        rejectedSituations.forEach { (situation) in
            XCTAssertFalse(
                self.action.acceptsArguments(
                    ActionArguments(
                        value: value,
                        with: situation
                    )
                )
            )
        }
    }
}


