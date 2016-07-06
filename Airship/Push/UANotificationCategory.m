/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
 * The actions to display when space is limited.
 */
@property(nonatomic, copy) NSArray<UANotificationAction *> *minimalActions;

/**
 * The intents supported by notifications of this category.
 *
 * Note: This property is only applicable on iOS 10 and above.
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *intentIdentifiers;

/**
 * Options for how to handle notifications of this type.
 */
@property(nonatomic, assign) UNNotificationCategoryOptions options;

@end

@implementation UANotificationCategory

- (instancetype)initWithIdentifier:(NSString *)identifier
                           actions:(NSArray<UANotificationAction *> *)actions
                    minimalActions:(NSArray<UANotificationAction *> *)minimalActions
                 intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                           options:(UNNotificationCategoryOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.actions = actions;
        self.minimalActions = actions;
        self.intentIdentifiers = intentIdentifiers;
        self.options = options;
    }

    return self;
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                        minimalActions:(NSArray<UANotificationAction *> *)minimalActions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UNNotificationCategoryOptions)options {

    return [[self alloc] initWithIdentifier:identifier
                                    actions:actions
                             minimalActions:minimalActions
                          intentIdentifiers:intentIdentifiers
                                    options:options];

}

- (UIUserNotificationCategory *)asUIUserNotificationCategory {
    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    category.identifier = self.identifier;

    NSArray *defaultActions = self.actions;
    NSMutableArray *defaultUIActions = [NSMutableArray array];
    for (UANotificationAction *uaAction in defaultActions) {
        [defaultUIActions addObject:[uaAction asUIUserNotificationAction]];
    }

    [category setActions:defaultUIActions forContext:UIUserNotificationActionContextDefault];

    NSArray *minimalActions = self.minimalActions;
    NSMutableArray *minimalUIActions = [NSMutableArray array];
    for (UANotificationAction *uaAction in minimalActions) {
        [minimalUIActions addObject:[uaAction asUIUserNotificationAction]];
    }

    [category setActions:minimalUIActions forContext:UIUserNotificationActionContextMinimal];

    return category;
}

- (UNNotificationCategory *)asUNNotificationCategory {
    NSMutableArray *actions = [NSMutableArray array];
    NSMutableArray *minimalActions = [NSMutableArray array];

    for (UANotificationAction *action in self.actions) {
        [actions addObject:[action asUNNotificationAction]];
    }

    for (UANotificationAction *minimalAction in self.minimalActions) {
        [minimalActions addObject:[minimalAction asUNNotificationAction]];
    }

    return [UNNotificationCategory categoryWithIdentifier:self.identifier
                                                  actions:actions
                                           minimalActions:minimalActions
                                        intentIdentifiers:self.intentIdentifiers
                                                  options:self.options];
}

- (BOOL)isEqualToUIUserNotificationCategory:(UIUserNotificationCategory *)category {
    NSArray *minimalUAActions = self.minimalActions;
    NSArray *defaultUAActions = self.actions;

    NSArray *minimalUIActions = [category actionsForContext:UIUserNotificationActionContextMinimal];
    NSArray *defaultUIActions = [category actionsForContext:UIUserNotificationActionContextDefault];

    if (minimalUAActions.count != minimalUIActions.count || defaultUAActions.count != defaultUIActions.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < minimalUAActions.count; i++) {
        UANotificationAction *uaAction = minimalUAActions[i];
        UIUserNotificationAction *uiAction = minimalUIActions[i];
        if (![uaAction isEqualToUIUserNotificationAction:(UIUserNotificationAction *)uiAction]) {
            return NO;
        }
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
    if (self.minimalActions.count != category.minimalActions.count || self.actions.count != category.actions.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < self.minimalActions.count; i++) {
        UANotificationAction *uaAction = self.minimalActions[i];
        UNNotificationAction *unAction = category.minimalActions[i];
        if (![uaAction isEqualToUNNotificationAction:unAction]) {
            return NO;
        }
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

    if (!(self.options == category.options)) {
        return NO;
    }

    return [self.identifier isEqualToString:category.identifier];
}

@end
