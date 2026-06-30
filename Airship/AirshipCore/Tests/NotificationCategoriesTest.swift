// Copyright Airship and Contributors

import Testing

@testable import AirshipCore
import Foundation
import UserNotifications

@Suite struct NotificationCategoriesTest {

    @Test
    func testDefaultCategories() {
        let categories = NotificationCategories.defaultCategories()
        #expect(37 == categories.count)

        // Require auth defaults to true for background actions
        categories.forEach { category in
            category.actions
                .filter({ !$0.options.contains(.foreground) })
                .forEach { action in
                    #expect(action.options.contains(.authenticationRequired))
                }
        }
    }

    @Test
    func testDefaultCategoriesOverrideAuth() {
        let categories = NotificationCategories.defaultCategories(withRequireAuth: false)
        #expect(37 == categories.count)

        // Verify require auth is false for background actions
        categories.forEach { category in
            category.actions
                .filter({ !$0.options.contains(.foreground) })
                .forEach { action in
                    #expect(!(action.options.contains(.authenticationRequired)))
                }
        }
    }


    @Test
    func testCreateFromPlist() {
        let plist = Bundle(for: BundleToken.self).path(forResource: "CustomNotificationCategories", ofType: "plist")!
        let categories = NotificationCategories.createCategories(fromFile: plist)

        #expect(4 == categories.count)

        // Share category
        let share = categories.first(where: { $0.identifier == "share_category" })
        #expect(share != nil)
        #expect(1 == share?.actions.count)

        // Share action in share category
        let shareAction = share?.actions.first(where: { $0.identifier == "share_button" })
        #expect(shareAction != nil)
        #expect("Share" == shareAction?.title)
        #expect(shareAction!.options.contains(.foreground))
        #expect(!(shareAction!.options.contains(.authenticationRequired)))
        #expect(!(shareAction!.options.contains(.destructive)))

        // Yes no category
        let yesNo = categories.first(where: { $0.identifier == "yes_no_category" })
        #expect(yesNo != nil)
        #expect(2 == yesNo?.actions.count)

        // Yes action in yes no category
        let yesAction = yesNo?.actions.first(where: { $0.identifier == "yes_button" })
        #expect(yesAction != nil)
        #expect("Yes" == yesAction?.title)
        #expect(yesAction!.options.contains(.foreground))
        #expect(!(yesAction!.options.contains(.authenticationRequired)))
        #expect(!(yesAction!.options.contains(.destructive)))

        // No action in yes no category
        let noAction = yesNo?.actions.first(where: { $0.identifier == "no_button" })
        #expect(noAction != nil)
        #expect("No" == noAction?.title)

        #expect(!(noAction!.options.contains(.foreground)))
        #expect(noAction!.options.contains(.authenticationRequired))
        #expect(noAction!.options.contains(.destructive))

        // text_input category
        let textInput = categories.first(where: { $0.identifier == "text_input_category" })
        #expect(textInput != nil)
        #expect(1 == textInput?.actions.count)

        // Follow action in follow category
        let textInputAction = textInput?.actions.first(where: { $0.identifier == "text_input" }) as? UNTextInputNotificationAction
        #expect(textInputAction != nil)

        // Test when 'title_resource' value does not exist will fall back to 'title' value
        #expect("TextInput" == textInputAction?.title)
        #expect("text_input_button" == textInputAction?.textInputButtonTitle)
        #expect("placeholder_text" == textInputAction?.textInputPlaceholder)
        #expect(textInputAction!.options.contains(.foreground))
        #expect(!(textInputAction!.options.contains(.authenticationRequired)))
        #expect(!(textInputAction!.options.contains(.destructive)))

        // Follow category
        let follow = categories.first(where: { $0.identifier == "follow_category" })
        #expect(follow != nil)
        #expect(1 == follow?.actions.count)

        // Follow action in follow category
        let followAction = follow?.actions.first(where: { $0.identifier == "follow_button" })
        #expect(followAction != nil)

        // Test when 'title_resource' value does not exist will fall back to 'title' value
        #expect("FollowMe" == followAction?.title)
        #expect(followAction!.options .contains(.foreground))
        #expect(!(followAction!.options.contains(.authenticationRequired)))
        #expect(!(followAction!.options.contains(.destructive)))
    }

    @Test
    func testDoesNotCreateCategoryMissingTitle() {
        let actions = [
            ["identifier": "yes", "foreground": true, "authenticationRequired": true],
            ["identifier": "no", "foreground": false, "destructive": true, "authenticationRequired": false]
        ]

        #expect(NotificationCategories.createCategory("category", actions: actions) == nil)
    }

    @Test
    func testCreateFromInvalidPlist() {
        let categories = NotificationCategories.createCategories(fromFile: "no file")
        #expect(0 == categories.count, "No categories should be created.")
    }

    @Test
    func testCreateCategory() {
        let actions = [
            ["identifier": "yes", "foreground": true, "title": "Yes", "authenticationRequired": true],
            ["identifier": "no", "foreground": false, "title": "No", "destructive": true, "authenticationRequired": false]
        ]

        let category = NotificationCategories.createCategory("category", actions: actions)

        // Yes action
        let yesAction = category?.actions.first(where: { $0.identifier == "yes" })
        #expect(yesAction != nil)
        #expect("Yes" == yesAction?.title)

        #expect(yesAction!.options.contains(.foreground))
        #expect(yesAction!.options.contains(.authenticationRequired))
        #expect(!(yesAction!.options.contains(.destructive)))

        // No action
        let noAction = category?.actions.first(where: { $0.identifier == "no" })
        #expect(noAction != nil)
        #expect("No" == noAction?.title)

        #expect(!(noAction!.options.contains(.foreground)))
        #expect(!(noAction!.options.contains(.authenticationRequired)))
        #expect(noAction!.options.contains(.destructive))
    }
}

private final class BundleToken {}
