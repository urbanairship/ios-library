/* Copyright 2017 Urban Airship and Contributors */


#import "UANotificationCategory.h"
#import "UANotificationAction.h"

@interface UANotificationCategory ()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSArray<UANotificationAction *> *actions;

/**
 * The intents supported by notifications of this category.
 *
 * Note: This property is only applicable on iOS 10 and above.
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *intentIdentifiers;

/**
 * Options for how to handle notifications of this type.
 */
@property(nonatomic, assign) UANotificationCategoryOptions options;

@end

@implementation UANotificationCategory

- (instancetype)initWithIdentifier:(NSString *)identifier
                           actions:(NSArray<UANotificationAction *> *)actions
                 intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                           options:(UANotificationCategoryOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.actions = actions;
        self.intentIdentifiers = intentIdentifiers;
        self.options = options;
    }

    return self;
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UANotificationCategoryOptions)options {

    return [[self alloc] initWithIdentifier:identifier
                                    actions:actions
                          intentIdentifiers:intentIdentifiers
                                    options:options];

}

#if !TARGET_OS_TV    // UIUserNotificationCategory, UIUserNotificationAction and UNNotificationCategory not available on tvOS
- (UIUserNotificationCategory *)asUIUserNotificationCategory {
    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    category.identifier = self.identifier;

    NSArray *uaActions = self.actions;
    NSMutableArray *uiActions = [NSMutableArray array];
    for (UANotificationAction *uaAction in uaActions) {
        UIUserNotificationAction *converted = [uaAction asUIUserNotificationAction];
        if (converted) {
            [uiActions addObject:converted];
        }
    }

    [category setActions:uiActions forContext:UIUserNotificationActionContextDefault];
    [category setActions:uiActions forContext:UIUserNotificationActionContextMinimal];

    return category;
}

- (UNNotificationCategory *)asUNNotificationCategory {
    NSMutableArray *actions = [NSMutableArray array];

    for (UANotificationAction *action in self.actions) {
        UNNotificationAction *converted = [action asUNNotificationAction];
        if (converted) {
            [actions addObject:converted];
        }
    }

    // Prevents iOS 10 beta crash
    if ([UNNotificationCategory respondsToSelector:@selector(categoryWithIdentifier:actions:intentIdentifiers:options:)]) {
        return [UNNotificationCategory categoryWithIdentifier:self.identifier
                                                      actions:actions
                                            intentIdentifiers:self.intentIdentifiers
                                                      options:(UNNotificationCategoryOptions)self.options];
    } else {
        return nil;
    }
}

- (BOOL)isEqualToUIUserNotificationCategory:(UIUserNotificationCategory *)category {
    NSArray *defaultUAActions = self.actions;

    NSArray *defaultUIActions = [category actionsForContext:UIUserNotificationActionContextDefault];

    if (defaultUAActions.count != defaultUIActions.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < defaultUAActions.count; i++) {
        UANotificationAction *uaAction = defaultUAActions[i];
        UIUserNotificationAction *uiAction = defaultUIActions[i];
        if (![uaAction isEqualToUIUserNotificationAction:(UIUserNotificationAction *)uiAction]) {
            return NO;
        }
    }

    // identifiers are nullable, so they match as long as they are either equal or both nil
    return [self.identifier isEqualToString:category.identifier] || (!self.identifier && !category.identifier);
}

- (BOOL)isEqualToUNNotificationCategory:(UNNotificationCategory *)category {
    if (self.actions.count != category.actions.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < self.actions.count; i++) {
        UANotificationAction *uaAction = self.actions[i];
        UNNotificationAction *unAction = category.actions[i];
        if (![uaAction isEqualToUNNotificationAction:unAction]) {
            return NO;
        }
    }

    if (![self.intentIdentifiers isEqualToArray:category.intentIdentifiers]) {
        return NO;
    }

    if (!((NSUInteger)self.options == (NSUInteger)category.options)) {
        return NO;
    }

    return [self.identifier isEqualToString:category.identifier];
}
#endif

@end
