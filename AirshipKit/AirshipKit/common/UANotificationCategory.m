/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UANotificationCategory+Internal.h"
#import "UANotificationAction+Internal.h"

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

@end
