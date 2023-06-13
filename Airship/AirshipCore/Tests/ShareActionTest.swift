/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ShareActionTest: XCTestCase {

    private let action: ShareAction = ShareAction()

    func testAcceptsArguments() async throws {
        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush
        ]

        let rejectedSituations = [
            ActionSituation.backgroundPush,
            ActionSituation.backgroundInteractiveButton
        ]

        for situation in validSituations {
            let args = ActionArguments(value: AirshipJSON.string("some valid text"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertTrue(result)
        }


        for situation in rejectedSituations {
            let args = ActionArguments(value: AirshipJSON.string("some valid text"), situation: situation)
            let result = await self.action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }
}


