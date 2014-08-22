#import "UADefaultUserNotificationCategories.h"

@implementation UADefaultUserNotificationCategories


+ (NSSet *)defaultCategories {
    return [self defaultCategoriesRequireAuth:YES];
}

+ (NSSet *)defaultCategoriesRequireAuth:(BOOL)requireAuth {
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
    NSArray *actions =@[@{@"identifier": @"yes",
                          @"foreground": @YES,
                          @"title": @"Yes"},
                        @{@"identifier": @"no",
                          @"foreground": @NO,
                          @"title": @"No",
                          @"auth":@(requireAuth)}];

    return [self createCategory:@"ua_yes_no_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createYesNoBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @NO,
                           @"title": @"Yes",
                           @"auth": @(requireAuth)},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title": @"No",
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_yes_no_background" actions:actions];
}


+ (UIUserNotificationCategory *)createShopNowCategory {
    NSArray *actions = @[@{@"identifier": @"shop_now",
                           @"foreground": @YES,
                           @"title": @"Shop Now"}];

    return [self createCategory:@"ua_shop_now" actions:actions];
}

+ (UIUserNotificationCategory *)createBuyNowCategory {
    NSArray *actions = @[@{@"identifier": @"buy_now",
                           @"foreground": @YES,
                           @"title": @"Buy Now"}];

    return [self createCategory:@"ua_buy_now" actions:actions];
}

+ (UIUserNotificationCategory *)createFollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"follow",
                           @"foreground": @NO,
                           @"title": @"Follow",
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_follow" actions:actions];
}


+ (UIUserNotificationCategory *)createUnfollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"unfollow",
                           @"foreground": @NO,
                           @"title": @"Unfollow",
                           @"destructive": @YES,
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_unfollow" actions:actions];
}

+ (UIUserNotificationCategory *)createOptInCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_in",
                           @"foreground": @NO,
                           @"title": @"Opt-in",
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_opt_in" actions:actions];
}

+ (UIUserNotificationCategory *)createOptOutCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_out",
                           @"foreground": @NO,
                           @"title": @"Opt-out",
                           @"destructive": @YES,
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_opt_out" actions:actions];
}

+ (UIUserNotificationCategory *)createRemindMeLaterCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"remind",
                           @"foreground": @NO,
                           @"title": @"Remind Me Later",
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_remind_me_later" actions:actions];
}

+ (UIUserNotificationCategory *)createShareCategory {
    NSArray *actions = @[@{@"identifier": @"share",
                           @"foreground": @YES,
                           @"title": @"Share"}];

    return [self createCategory:@"ua_share" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineForegroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions =@[@{@"identifier": @"accept",
                          @"foreground": @YES,
                          @"title": @"Accept"},
                        @{@"identifier": @"decline",
                          @"foreground": @NO,
                          @"title": @"Decline",
                          @"auth":@(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"accept",
                           @"foreground": @NO,
                           @"title": @"Accept",
                           @"auth": @(requireAuth)},
                         @{@"identifier": @"decline",
                           @"foreground": @NO,
                           @"title": @"Decline",
                           @"auth": @(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_background" actions:actions];
}

+ (UIUserNotificationCategory *)createCategory:(NSString *)categoryId actions:(NSArray *)actionDefinitions {
    NSMutableArray *actions = [NSMutableArray array];

    for (NSDictionary *actionDefinition in actionDefinitions) {
        UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
        action.destructive = [actionDefinition[@"destructive"] boolValue];
        action.activationMode = actionDefinition[@"foreground"] ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
        action.title = actionDefinition[@"title"];
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
