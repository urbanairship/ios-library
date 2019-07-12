/* Copyright Airship and Contributors */

import XCTest

extension XCUIApplication {
    func checkLocalization() {
        let predicate = NSPredicate(format: "label contains[c] %@", "ua_")

        // Check buttons labels, static text, and tab bar labels
        let buttonQuery = self.buttons.containing(predicate)
        let staticTextQuery = self.staticTexts.containing(predicate)
        let tableStaticTextQuery = self.tables.staticTexts.containing(predicate)
        let tabBarButtonQuery = self.tabs.containing(predicate)

        for query in [buttonQuery, staticTextQuery, tabBarButtonQuery, tableStaticTextQuery] {
            // A query found a visible label prepended with ua_
            XCTAssertFalse(query.count > 0)
        }
    }
}
