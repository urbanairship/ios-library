/* Copyright Airship and Contributors */

import XCTest

class CoreUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        // Ensure we don't try to continue to run after entering an unexpected state
        continueAfterFailure = false
        XCUIApplication().launch()

        self.addUIInterruptionMonitor(withDescription: "Alert handler") { (element) -> Bool in

            if element.label == "Notice" {
                element.buttons["Disable Warning"].tap()
            }

            return true
        }
    }

    /// Tests app launches to expected initial home screen
    func testHomeView() {
        // Note: these string identifiers are accessibility identifers set in the storyboard
        let airshipMark = app.images["airshipMark"]

        XCTAssert(airshipMark.exists)

        // Check localization on home view
        app.checkLocalization()
    }

    func testMessageCenterView() {
        app.tabBars.buttons["Message Center"].tap()

        // Inside message center view
        app.checkLocalization()

        let messageCenterNavigationBar = app.navigationBars["Message Center"]
        messageCenterNavigationBar.buttons["Edit"].tap()
        messageCenterNavigationBar.buttons["Cancel"].tap()
    }
}
