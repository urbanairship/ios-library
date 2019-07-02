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

    // This method requires software keyboard to be enabled on the simulator
    func typeInTestString(_ str:String, withReturn:Bool) {
        for c in str {
            let charKey = self.keys[String(c)]

            if c.isWhitespace {
                self.keys["space"].tap()
                continue
            }

            if c == "_" {
                let more = self.keys["more"]
                let shift = self.keys["shift"]

                more.tap()
                shift.tap()
                charKey.tap()
                shift.tap()
                more.tap()
                continue
            }

            if c.isNumber {
                // Hit "more" key to access numbers in software keyboard
                let more = self.keys["more"]
                more.tap()
                charKey.tap()
                more.tap()
                continue
            }

            charKey.tap()
        }

        if withReturn {
            self/*@START_MENU_TOKEN@*/.buttons["Return"]/*[[".keyboards",".buttons[\"return\"]",".buttons[\"Return\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        }
    }
}
