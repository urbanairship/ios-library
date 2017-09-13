/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <UserNotifications/UserNotifications.h>
#import "UANotificationCategories+Internal.h"
#import "UANotificationCategory.h"
#import "UANotificationAction.h"
#import "UATextInputNotificationAction.h"

@interface UANotificationCategoriesTest : UABaseTest

@end

@implementation UANotificationCategoriesTest

- (void)testDefaultCategories {
    NSSet *categories = [UANotificationCategories defaultCategories];
    XCTAssertEqual(37, categories.count);

    // Require auth defaults to true for background actions
    for (UANotificationCategory *category in categories) {
        for (UANotificationAction *action in category.actions) {
            if (!(action.options & UNNotificationActionOptionForeground)) {
                XCTAssertTrue(action.options & UNNotificationActionOptionAuthenticationRequired);
            }
        }
    }
}

- (void)testDefaultCategoriesOverrideAuth {
    NSSet *categories = [UANotificationCategories defaultCategoriesWithRequireAuth:NO];
    XCTAssertEqual(37, categories.count);

    // Verify require auth is false for background actions
    for (UANotificationCategory *category in categories) {
        for (UANotificationAction *action in category.actions) {
            if (!(action.options & UNNotificationActionOptionForeground)) {
                XCTAssertFalse(action.options & UNNotificationActionOptionAuthenticationRequired);
            }
        }
    }
}

- (void)testCreateFromPlist {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"CustomNotificationCategories" ofType:@"plist"];
    NSSet *categories = [UANotificationCategories createCategoriesFromFile:plistPath];

    XCTAssertEqual(4, categories.count);

    // Share category
    UANotificationCategory *share = [self findCategoryById:@"share_category" set:categories];
    XCTAssertNotNil(share);
    XCTAssertEqual(1, share.actions.count);

    // Share action in share category
    UANotificationAction  *shareAction = [self findActionById:@"share_button" category:share];
    XCTAssertNotNil(shareAction);
    XCTAssertEqualObjects(@"Share", shareAction.title);
    XCTAssertTrue(shareAction.options & UNNotificationActionOptionForeground);
    XCTAssertFalse(shareAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertFalse(shareAction.options & UNNotificationActionOptionDestructive);

    // Yes no category
    UANotificationCategory *yesNo = [self findCategoryById:@"yes_no_category" set:categories];
    XCTAssertNotNil(yesNo);
    XCTAssertEqual(2, yesNo.actions.count);

    // Yes action in yes no category
    UANotificationAction  *yesAction = [self findActionById:@"yes_button" category:yesNo];
    XCTAssertNotNil(yesAction);
    XCTAssertEqualObjects(@"Yes", yesAction.title);
    XCTAssertTrue(yesAction.options & UNNotificationActionOptionForeground);
    XCTAssertFalse(yesAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertFalse(yesAction.options & UNNotificationActionOptionDestructive);

    // No action in yes no category
    UANotificationAction  *noAction = [self findActionById:@"no_button" category:yesNo];
    XCTAssertNotNil(noAction);
    XCTAssertEqualObjects(@"No", noAction.title);

    XCTAssertFalse(noAction.options & UNNotificationActionOptionForeground);
    XCTAssertTrue(noAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertTrue(noAction.options & UNNotificationActionOptionDestructive);

    // text_input category
    UANotificationCategory *textInput = [self findCategoryById:@"text_input_category" set:categories];
    XCTAssertNotNil(textInput);
    XCTAssertEqual(1, textInput.actions.count);
    
    // Follow action in follow category
    UATextInputNotificationAction *textInputAction = (UATextInputNotificationAction *)[self findActionById:@"text_input" category:textInput];
    XCTAssertNotNil(textInputAction);
    
    // Test when 'title_resource' value does not exist will fall back to 'title' value
    XCTAssertEqualObjects(@"TextInput", textInputAction.title);
    XCTAssertEqualObjects(@"text_input_button", textInputAction.textInputButtonTitle);
    XCTAssertEqualObjects(@"placeholder_text", textInputAction.textInputPlaceholder);
    XCTAssertTrue(textInputAction.options & UNNotificationActionOptionForeground);
    XCTAssertFalse(textInputAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertFalse(textInputAction.options & UNNotificationActionOptionDestructive);
    
    // Follow category
    UANotificationCategory *follow = [self findCategoryById:@"follow_category" set:categories];
    XCTAssertNotNil(follow);
    XCTAssertEqual(1, follow.actions.count);

    // Follow action in follow category
    UANotificationAction  *followAction = [self findActionById:@"follow_button" category:follow];
    XCTAssertNotNil(followAction);

    // Test when 'title_resource' value does not exist will fall back to 'title' value
    XCTAssertEqualObjects(@"FollowMe", followAction.title);
    XCTAssertTrue(followAction.options & UNNotificationActionOptionForeground);
    XCTAssertFalse(followAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertFalse(followAction.options & UNNotificationActionOptionDestructive);
}



- (void)testDoesNotCreateCategoryMissingTitle {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @YES,
                           @"authenticationRequired": @YES},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"destructive": @YES,
                           @"authenticationRequired": @NO}];

    UANotificationCategory *category = [UANotificationCategories createCategory:@"category" actions:actions];

    XCTAssertNil(category);
}

- (void)testCreateFromInvalidPlist {
    NSSet *categories = [UANotificationCategories createCategoriesFromFile:@"i dont exist!"];
    XCTAssertEqual(0, categories.count, "No categories should be created.");
}

- (void)testCreateCategory {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @YES,
                           @"title": @"Yes",
                           @"authenticationRequired": @YES},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title": @"No",
                           @"destructive": @YES,
                           @"authenticationRequired": @NO}];


    UANotificationCategory *category = [UANotificationCategories createCategory:@"category" actions:actions];

    // Yes action
    UANotificationAction  *yesAction = [self findActionById:@"yes" category:category];
    XCTAssertNotNil(yesAction);
    XCTAssertEqualObjects(@"Yes", yesAction.title);

    XCTAssertTrue(yesAction.options & UNNotificationActionOptionForeground);
    XCTAssertTrue(yesAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertFalse(yesAction.options & UNNotificationActionOptionDestructive);

    // No action
    UANotificationAction  *noAction = [self findActionById:@"no" category:category];
    XCTAssertNotNil(noAction);
    XCTAssertEqualObjects(@"No", noAction.title);

    XCTAssertFalse(noAction.options & UNNotificationActionOptionForeground);
    XCTAssertFalse(noAction.options & UNNotificationActionOptionAuthenticationRequired);
    XCTAssertTrue(noAction.options & UNNotificationActionOptionDestructive);
}


- (UANotificationCategory *)findCategoryById:(NSString *)identifier set:(NSSet *)categories {
    for (UANotificationCategory *category in categories) {
        if ([category.identifier isEqualToString:identifier]) {
            return category;
        }
    }

    return nil;
}

- (UANotificationAction  *)findActionById:(NSString *)identifier category:(UANotificationCategory *)category {
    for (UANotificationAction  *action in category.actions) {
        if ([action.identifier isEqualToString:identifier]) {
            return action;
        }
    }

    return nil;
}

@end
