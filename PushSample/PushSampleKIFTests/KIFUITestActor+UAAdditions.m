/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "KIFUITestActor+UAAdditions.h"
#import "UATestPushDelegate.h"
#import "UAUtils.h"
#import "UAirship.h"

#define kPushWait 120.0 // Wait up to 120 seconds for push before marking test failed

@implementation KIFUITestActor (UAAdditions)

// This method adds an observer for UIApplicationDidFinishLaunchingNotification
+ (void)load {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:[KIFUITestActor class] selector:@selector(setNotificationProperties:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

// This method sets the flags to work around the iOS 8 issue.
+ (void)setNotificationProperties:(NSNotification *)notification {
    // don't require settings app to disable push
    [UAirship push].requireSettingsAppToDisableUserNotifications = NO;
    [UAirship push].allowUnregisteringUserNotificationTypes = NO;
}

// This method stores the uniqueID for the expected push notification
- (void)setUniqueID:(NSString *)alertID {
    return [self runBlock:^KIFTestStepResult(NSError *__autoreleasing *error) {
        NSLog(@"Set uniqueID.");
        UATestPushDelegate *pushDelegate = (UATestPushDelegate*) [UAirship push].pushNotificationDelegate;
        pushDelegate.uniqueID = alertID;
        return KIFTestStepResultSuccess;
    }];
}

// This method sends the push notification with the uniqueID and verifies the expected push arrived
- (void)sendAndWaitForNotification:(NSString *)description sendPushBlock:(SendPushBlock)sendPushBlock {
    NSString *alertID = [NSUUID UUID].UUIDString;
    [self setUniqueID:alertID];

    return [self runBlock:^KIFTestStepResult(NSError **error) {
        NSLog(@"%@", description);
        sendPushBlock(alertID);
        [[self usingTimeout:kPushWait] waitForTappableViewWithAccessibilityLabel:alertID traits:UIAccessibilityTraitButton];
        [self tapViewWithAccessibilityLabel:alertID traits:UIAccessibilityTraitButton];
        return KIFTestStepResultSuccess;
    }];
}

// This method verifies the pushEnabled value
- (void)verifyPushEnabled:(BOOL)enabled {
    return [self runBlock:^KIFTestStepResult(NSError **error) {
        NSLog(@"Verify PushEnabled.");
        KIFTestCondition(([UAirship push].userPushNotificationsEnabled == enabled), error, @"PushEnabled does not match expected value.");
        return KIFTestStepResultSuccess;
    }];
}

@end
