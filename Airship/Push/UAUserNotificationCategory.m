/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UAUserNotificationCategory.h"
#import "UAUserNotificationCategory+Internal.h"
#import "UAUserNotificationAction.h"

@interface UAUserNotificationCategory ()
@property(nonatomic, copy) NSString *identifier;
@end

@implementation UAUserNotificationCategory

/**
 * This implementation does nothing, because in practice one will always create
 * the mutable variant.
 */
- (NSArray *)actionsForContext:(UIUserNotificationActionContext)context {
    return nil;
}

- (UIUserNotificationCategory *)asUIUserNotificationCategory {
    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    category.identifier = self.identifier;

    for (int ctx=UIUserNotificationActionContextDefault; ctx <= UIUserNotificationActionContextMinimal; ctx++) {
        NSArray *uaActions = [self actionsForContext:(UIUserNotificationActionContext)ctx];
        NSMutableArray *uiActions = [NSMutableArray array];
        for (UAUserNotificationAction *uaAction in uaActions) {
            UIMutableUserNotificationAction *uiAction = [[UIMutableUserNotificationAction alloc] init];
            uiAction.identifier = uaAction.identifier;
            uiAction.title = uaAction.title;
            uiAction.authenticationRequired = uaAction.authenticationRequired;
            uiAction.activationMode = (UIUserNotificationActivationMode)uaAction.activationMode;
            uiAction.destructive = uaAction.destructive;

            [uiActions addObject:uiAction];
        }

        [category setActions:uiActions forContext:(UIUserNotificationActionContext)ctx];
    }

    return category;
}

@end
