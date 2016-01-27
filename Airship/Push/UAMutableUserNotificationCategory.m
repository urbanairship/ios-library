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

#import "UAMutableUserNotificationCategory.h"
#import "UAMutableUserNotificationAction.h"

@interface UAMutableUserNotificationCategory ()
@property(nonatomic, strong) NSMutableDictionary *actions;
@end

@implementation UAMutableUserNotificationCategory

@dynamic identifier;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.actions = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)categoryWithUIUserNotificationCategory:(UIUserNotificationCategory *)uiCategory {
    UAMutableUserNotificationCategory *uaCategory = [[self alloc] init];
    uaCategory.identifier = uiCategory.identifier;

    NSArray *minimalUIActions = [uiCategory actionsForContext:UIUserNotificationActionContextMinimal];
    NSArray *defaultUIActions = [uiCategory actionsForContext:UIUserNotificationActionContextDefault];

    NSMutableArray *minimalUAActions = [NSMutableArray array];
    NSMutableArray *defaultUAActions = [NSMutableArray array];

    for (UIUserNotificationAction *uiAction in minimalUIActions) {
        [minimalUAActions addObject:[UAMutableUserNotificationAction actionWithUIUserNotificationAction:uiAction]];
    }

    for (UIUserNotificationAction *uiAction in defaultUIActions) {
        [defaultUAActions addObject:[UAMutableUserNotificationAction actionWithUIUserNotificationAction:uiAction]];
    }

    [uaCategory setActions:minimalUAActions forContext:UIUserNotificationActionContextMinimal];
    [uaCategory setActions:defaultUAActions forContext:UIUserNotificationActionContextDefault];

    return uaCategory;
}

- (void)setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context {
    [self.actions setObject:actions forKey:@(context)];
}

- (NSArray *)actionsForContext:(UIUserNotificationActionContext)context {
    return self.actions[@(context)];
}

@end
