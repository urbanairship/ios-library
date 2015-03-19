/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "UAUserNotificationCategories.h"
#import "UAUserNotificationCategory.h"
#import "UAUserNotificationAction.h"

@interface UAUserNotificationCategoriesTest : XCTestCase

@end

@implementation UAUserNotificationCategoriesTest

- (void)testCreateFromPlist {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"CustomNotificationCategories" ofType:@"plist"];
    NSSet *categories = [UAUserNotificationCategories createCategoriesFromFile:plistPath];

    XCTAssertEqual(3, categories.count);

    // Share category
    UAUserNotificationCategory *share = [self findCategoryById:@"share_category" set:categories];
    XCTAssertNotNil(share);
    XCTAssertEqual(1, [share actionsForContext:UIUserNotificationActionContextDefault].count);
    XCTAssertEqual(1, [share actionsForContext:UIUserNotificationActionContextMinimal].count);

    // Share action in share category
    UAUserNotificationAction  *shareAction = [self findActionById:@"share_button" category:share];
    XCTAssertNotNil(shareAction);
    XCTAssertEqualObjects(@"Share", shareAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeForeground, shareAction.activationMode);
    XCTAssertFalse(shareAction.authenticationRequired);
    XCTAssertFalse(shareAction.destructive);


    // Yes no category
    UAUserNotificationCategory *yesNo = [self findCategoryById:@"yes_no_category" set:categories];
    XCTAssertNotNil(yesNo);
    XCTAssertEqual(2, [yesNo actionsForContext:UIUserNotificationActionContextDefault].count);
    XCTAssertEqual(2, [yesNo actionsForContext:UIUserNotificationActionContextMinimal].count);

    // Yes action in yes no category
    UAUserNotificationAction  *yesAction = [self findActionById:@"yes_button" category:yesNo];
    XCTAssertNotNil(yesAction);
    XCTAssertEqualObjects(@"Yes", yesAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeForeground, yesAction.activationMode);
    XCTAssertFalse(yesAction.authenticationRequired);
    XCTAssertFalse(yesAction.destructive);

    // No action in yes no category
    UAUserNotificationAction  *noAction = [self findActionById:@"no_button" category:yesNo];
    XCTAssertNotNil(noAction);
    XCTAssertEqualObjects(@"No", noAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeBackground, noAction.activationMode);
    XCTAssertTrue(noAction.authenticationRequired);
    XCTAssertTrue(noAction.destructive);

    // Follow category
    UAUserNotificationCategory *follow = [self findCategoryById:@"follow_category" set:categories];
    XCTAssertNotNil(follow);
    XCTAssertEqual(1, [follow actionsForContext:UIUserNotificationActionContextDefault].count);
    XCTAssertEqual(1, [follow actionsForContext:UIUserNotificationActionContextMinimal].count);

    // Follow action in follow category
    UAUserNotificationAction  *followAction = [self findActionById:@"follow_button" category:follow];
    XCTAssertNotNil(followAction);
    // Test when 'title_resource' value does not exist will fall back to 'title' value
    XCTAssertEqualObjects(@"FollowMe", followAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeForeground, followAction.activationMode);
    XCTAssertFalse(followAction.authenticationRequired);
    XCTAssertFalse(followAction.destructive);
}

- (void)testDoesNotCreateCategoryMissingTitle {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @YES,
                           @"authenticationRequired": @YES},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"destructive": @YES,
                           @"authenticationRequired": @NO}];

    UAUserNotificationCategory *category = [UAUserNotificationCategories createCategory:@"category" actions:actions];

    XCTAssertNil(category);
}

- (void)testCreateFromInvalidPlist {
    NSSet *categories = [UAUserNotificationCategories createCategoriesFromFile:@"i dont exist!"];
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


    UAUserNotificationCategory *category = [UAUserNotificationCategories createCategory:@"category" actions:actions];

    // Yes action
    UAUserNotificationAction  *yesAction = [self findActionById:@"yes" category:category];
    XCTAssertNotNil(yesAction);
    XCTAssertEqualObjects(@"Yes", yesAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeForeground, yesAction.activationMode);
    XCTAssertTrue(yesAction.authenticationRequired);
    XCTAssertFalse(yesAction.destructive);

    // No action
    UAUserNotificationAction  *noAction = [self findActionById:@"no" category:category];
    XCTAssertNotNil(noAction);
    XCTAssertEqualObjects(@"No", noAction.title);
    XCTAssertEqual(UIUserNotificationActivationModeBackground, noAction.activationMode);
    XCTAssertFalse(noAction.authenticationRequired);
    XCTAssertTrue(noAction.destructive);

}


- (UAUserNotificationCategory *)findCategoryById:(NSString *)identifier set:(NSSet *)categories {
    for (UAUserNotificationCategory *category in categories) {
        if ([category.identifier isEqualToString:identifier]) {
            return category;
        }
    }

    return nil;
}

- (UAUserNotificationAction  *)findActionById:(NSString *)identifier category:(UAUserNotificationCategory *)category {
    for (UAUserNotificationAction  *action in [category actionsForContext:UIUserNotificationActionContextMinimal]) {
        if ([action.identifier isEqualToString:identifier]) {
            return action;
        }
    }

    return nil;
}

@end
