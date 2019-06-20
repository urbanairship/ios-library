/* Copyright Airship and Contributors */

import XCTest

class CoreUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        // Ensure we don't try to continue to run after entering an unexpected state
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    /// Tests app launches to expected initial home screen
    func testHomeView() {
        // Note: these string identifiers are accessibility identifers set in the storyboard
        let airshipMark = app.images["airshipMark"]
        let enablePushButton = app.buttons["enablePushButton"]

        XCTAssert(airshipMark.exists)

        // Check button isn't missing localization
        XCTAssertFalse(enablePushButton.label.starts(with: "ua_"))

        // Enable push button appears and can be touched
        XCTAssert(enablePushButton.isEnabled)
        XCTAssert(enablePushButton.isHittable)
    }
}
