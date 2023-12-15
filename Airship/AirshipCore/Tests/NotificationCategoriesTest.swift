// Copyright Airship and Contributors

import XCTest

@testable import AirshipCore

final class NotificationCategoriesTest: XCTestCase {
    
    func testDefaultCategories() {
        let categories = NotificationCategories.defaultCategories()
        XCTAssertEqual(37, categories.count)
        
        // Require auth defaults to true for background actions
        categories.forEach { category in
            category.actions
                .filter({ !$0.options.contains(.foreground) })
                .forEach { action in
                    XCTAssert(action.options.contains(.authenticationRequired))
                }
        }
    }
    
    func testDefaultCategoriesOverrideAuth() {
        let categories = NotificationCategories.defaultCategories(withRequireAuth: false)
        XCTAssertEqual(37, categories.count)
        
        // Verify require auth is false for background actions
        categories.forEach { category in
            category.actions
                .filter({ !$0.options.contains(.foreground) })
                .forEach { action in
                    XCTAssertFalse(action.options.contains(.authenticationRequired))
                }
        }
    }
    
    
    func testCreateFromPlist() {
        let plist = Bundle(for: self.classForCoder).path(forResource: "CustomNotificationCategories", ofType: "plist")!
        let categories = NotificationCategories.createCategories(fromFile: plist)
        
        XCTAssertEqual(4, categories.count)
        
        // Share category
        let share = categories.first(where: { $0.identifier == "share_category" })
        XCTAssertNotNil(share)
        XCTAssertEqual(1, share?.actions.count)

        // Share action in share category
        let shareAction = share?.actions.first(where: { $0.identifier == "share_button" })
        XCTAssertNotNil(shareAction)
        XCTAssertEqual("Share", shareAction?.title)
        XCTAssertTrue(shareAction!.options.contains(.foreground))
        XCTAssertFalse(shareAction!.options.contains(.authenticationRequired))
        XCTAssertFalse(shareAction!.options.contains(.destructive))

        // Yes no category
        let yesNo = categories.first(where: { $0.identifier == "yes_no_category" })
        XCTAssertNotNil(yesNo)
        XCTAssertEqual(2, yesNo?.actions.count)

        // Yes action in yes no category
        let yesAction = yesNo?.actions.first(where: { $0.identifier == "yes_button" })
        XCTAssertNotNil(yesAction)
        XCTAssertEqual("Yes", yesAction?.title)
        XCTAssertTrue(yesAction!.options.contains(.foreground))
        XCTAssertFalse(yesAction!.options.contains(.authenticationRequired))
        XCTAssertFalse(yesAction!.options.contains(.destructive))

        // No action in yes no category
        let noAction = yesNo?.actions.first(where: { $0.identifier == "no_button" })
        XCTAssertNotNil(noAction)
        XCTAssertEqual("No", noAction?.title)

        XCTAssertFalse(noAction!.options.contains(.foreground))
        XCTAssertTrue(noAction!.options.contains(.authenticationRequired))
        XCTAssertTrue(noAction!.options.contains(.destructive))

        // text_input category
        let textInput = categories.first(where: { $0.identifier == "text_input_category" })
        XCTAssertNotNil(textInput)
        XCTAssertEqual(1, textInput?.actions.count)
        
        // Follow action in follow category
        let textInputAction = textInput?.actions.first(where: { $0.identifier == "text_input" }) as? UNTextInputNotificationAction
        XCTAssertNotNil(textInputAction)
        
        // Test when 'title_resource' value does not exist will fall back to 'title' value
        XCTAssertEqual("TextInput", textInputAction?.title)
        XCTAssertEqual("text_input_button", textInputAction?.textInputButtonTitle)
        XCTAssertEqual("placeholder_text", textInputAction?.textInputPlaceholder)
        XCTAssertTrue(textInputAction!.options.contains(.foreground))
        XCTAssertFalse(textInputAction!.options.contains(.authenticationRequired))
        XCTAssertFalse(textInputAction!.options.contains(.destructive))
        
        // Follow category
        let follow = categories.first(where: { $0.identifier == "follow_category" })
        XCTAssertNotNil(follow)
        XCTAssertEqual(1, follow?.actions.count)

        // Follow action in follow category
        let followAction = follow?.actions.first(where: { $0.identifier == "follow_button" })
        XCTAssertNotNil(followAction)

        // Test when 'title_resource' value does not exist will fall back to 'title' value
        XCTAssertEqual("FollowMe", followAction?.title)
        XCTAssertTrue(followAction!.options .contains(.foreground))
        XCTAssertFalse(followAction!.options.contains(.authenticationRequired))
        XCTAssertFalse(followAction!.options.contains(.destructive))
    }
    
    func testDoesNotCreateCategoryMissingTitle() {
        let actions = [
            ["identifier": "yes", "foreground": true, "authenticationRequired": true],
            ["identifier": "no", "foreground": false, "destructive": true, "authenticationRequired": false]
        ]
        
        XCTAssertNil(NotificationCategories.createCategory("category", actions: actions))
    }
    
    func testCreateFromInvalidPlist() {
        let categories = NotificationCategories.createCategories(fromFile: "no file")
        XCTAssertEqual(0, categories.count, "No categories should be created.")
    }
    
    func testCreateCategory() {
        let actions = [
            ["identifier": "yes", "foreground": true, "title": "Yes", "authenticationRequired": true],
            ["identifier": "no", "foreground": false, "title": "No", "destructive": true, "authenticationRequired": false]
        ]
        
        let category = NotificationCategories.createCategory("category", actions: actions)
        
        // Yes action
        let yesAction = category?.actions.first(where: { $0.identifier == "yes" })
        XCTAssertNotNil(yesAction)
        XCTAssertEqual("Yes", yesAction?.title)

        XCTAssertTrue(yesAction!.options.contains(.foreground))
        XCTAssertTrue(yesAction!.options.contains(.authenticationRequired))
        XCTAssertFalse(yesAction!.options.contains(.destructive))

        // No action
        let noAction = category?.actions.first(where: { $0.identifier == "no" })
        XCTAssertNotNil(noAction)
        XCTAssertEqual("No", noAction?.title)

        XCTAssertFalse(noAction!.options.contains(.foreground))
        XCTAssertFalse(noAction!.options.contains(.authenticationRequired))
        XCTAssertTrue(noAction!.options.contains(.destructive))
    }
}
