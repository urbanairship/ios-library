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

#import "UAUserNotificationCategories.h"

@implementation UAUserNotificationCategories

+ (NSSet *)defaultCategories {
    return [self defaultCategoriesWithRequireAuth:YES];
}

+ (NSSet *)defaultCategoriesWithRequireAuth:(BOOL)requireAuth {
    NSArray *categories = @[[self createYesNoForegroundCategoryRequireAuth:requireAuth],
                            [self createYesNoBackgroundCategoryRequireAuth:requireAuth],
                            [self createShopNowCategory],
                            [self createBuyNowCategory],
                            [self createFollowCategoryRequireAuth:requireAuth],
                            [self createUnfollowCategoryRequireAuth:requireAuth],
                            [self createOptInCategoryRequireAuth:requireAuth],
                            [self createOptOutCategoryRequireAuth:requireAuth],
                            [self createRemindMeLaterCategoryRequireAuth:requireAuth],
                            [self createShareCategory],
                            [self createAcceptOrDeclineForegroundCategoryRequireAuth:requireAuth],
                            [self createAcceptOrDeclineBackgroundCategoryRequireAuth:requireAuth]];

    return [NSSet setWithArray:categories];
}


+ (UIUserNotificationCategory *)createYesNoForegroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @YES,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_yes_no_foreground_yes",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Yes",
                                                                       "Button title for yes when app is in foreground")},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_yes_no_foreground_no",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"No",
                                                                       "Button title for no when app is in foreground"),
                           @"authenticationRequired":@(requireAuth)}];

    return [self createCategory:@"ua_yes_no_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createYesNoBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_yes_no_background_yes",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Yes",
                                                                       "Button title for yes when app is in background"),
                           @"authenticationRequired": @(requireAuth)},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_yes_no_background_no",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"No",
                                                                       "Button title for no when app is in background"),
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_yes_no_background" actions:actions];
}


+ (UIUserNotificationCategory *)createShopNowCategory {
    NSArray *actions = @[@{@"identifier": @"shop_now",
                           @"foreground": @YES,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_shop_now_shop_now",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Shop Now",
                                                                       "Button title to shop now")}];

    return [self createCategory:@"ua_shop_now" actions:actions];
}

+ (UIUserNotificationCategory *)createBuyNowCategory {
    NSArray *actions = @[@{@"identifier": @"buy_now",
                           @"foreground": @YES,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_buy_now_buy_now",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Buy Now",
                                                                       "Button title to buy now")}];

    return [self createCategory:@"ua_buy_now" actions:actions];
}

+ (UIUserNotificationCategory *)createFollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"follow",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_follow_follow",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Follow",
                                                                       "Button title to follow"),
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_follow" actions:actions];
}


+ (UIUserNotificationCategory *)createUnfollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"unfollow",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_unfollow_unfollow",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Unfollow",
                                                                       "Button title to unfollow"),
                           @"destructive": @YES,
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_unfollow" actions:actions];
}

+ (UIUserNotificationCategory *)createOptInCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_in",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_opt_in_opt_in",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Opt-in",
                                                                       "Button title to opt-in"),
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_opt_in" actions:actions];
}

+ (UIUserNotificationCategory *)createOptOutCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_out",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_opt_out_opt_out",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Opt-out",
                                                                       "Button title to opt-out"),
                           @"destructive": @YES,
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_opt_out" actions:actions];
}

+ (UIUserNotificationCategory *)createRemindMeLaterCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"remind",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_remind_me_later_remind",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Remind Me Later",
                                                                       "Button title to remind me later"),
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_remind_me_later" actions:actions];
}

+ (UIUserNotificationCategory *)createShareCategory {
    NSArray *actions = @[@{@"identifier": @"share",
                           @"foreground": @YES,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_share_share",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Share",
                                                                       "Button title to share")}];

    return [self createCategory:@"ua_share" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineForegroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"accept",
                           @"foreground": @YES,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_accept_decline_foreground_accept",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Accept",
                                                                       "Button title to accept when app is in foreground")},
                         @{@"identifier": @"decline",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_accept_decline_foreground_decline",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Decline",
                                                                       "Button title to decline when app is in foreground"),
                           @"authenticationRequired":@(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"accept",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_accept_decline_background_accept",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Accept",
                                                                       "Button title to accept when app is in background"),
                           @"authenticationRequired": @(requireAuth)},
                         @{@"identifier": @"decline",
                           @"foreground": @NO,
                           @"title": NSLocalizedStringWithDefaultValue(@"ua_accept_decline_background_decline",
                                                                       nil,
                                                                       [NSBundle mainBundle],
                                                                       @"Decline",
                                                                       "Button title to decline when app is in background"),
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_background" actions:actions];
}

+ (NSSet *)createCategoriesFromFile:(NSString *)path {
    NSDictionary *categoriesDictionary = [[NSDictionary alloc] initWithContentsOfFile:path];

    NSMutableSet *categories = [NSMutableSet set];

    for (NSString *categoryId in [categoriesDictionary allKeys]) {
        NSArray *actions = [categoriesDictionary valueForKey:categoryId];
        if (actions) {
            [categories addObject:[self createCategory:categoryId actions:actions]];
        }
    }

    return [NSSet setWithSet:categories];
}

+ (UIUserNotificationCategory *)createCategory:(NSString *)categoryId actions:(NSArray *)actionDefinitions {
    NSMutableArray *actions = [NSMutableArray array];

    for (NSDictionary *actionDefinition in actionDefinitions) {
        NSString *title;
        if (actionDefinition[@"title_resource"]) {
            title = NSLocalizedStringWithDefaultValue(actionDefinition[@"title_resource"], nil, [NSBundle mainBundle], actionDefinition[@"title"], nil);
        } else {
            title = actionDefinition[@"title"];
        }

        UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
        action.destructive = [actionDefinition[@"destructive"] boolValue];
        action.activationMode = [actionDefinition[@"foreground"] boolValue] ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
        action.title = title;
        action.identifier = actionDefinition[@"identifier"];
        action.authenticationRequired = [actionDefinition[@"authenticationRequired"] boolValue];
        [actions addObject:action];
    }

    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    [category setActions:actions forContext:UIUserNotificationActionContextMinimal];
    [category setActions:actions forContext:UIUserNotificationActionContextDefault];
    category.identifier = categoryId;

    return category;
}

@end
