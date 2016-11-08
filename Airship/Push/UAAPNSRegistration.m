/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory+Internal.h"

@implementation UAAPNSRegistration

-(void)getCurrentAuthorizationOptionsWithCompletionHandler:(void (^)(UANotificationOptions))completionHandler {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {

        UANotificationOptions mask = UANotificationOptionNone;

        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            if (settings.alertSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionAlert;
            }

            if (settings.soundSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionSound;
            }

            if (settings.badgeSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionBadge;
            }

            if (settings.carPlaySetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionCarPlay;
            }
        }

        completionHandler(mask);
    }];
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(void (^)())completionHandler {

    NSMutableSet *normalizedCategories;

    if (categories) {
        normalizedCategories = [NSMutableSet set];

        // Normalize our abstract categories to iOS-appropriate type
        for (UANotificationCategory *category in categories) {

            id normalizedCategory = [category asUNNotificationCategory];

            // iOS 10 beta this could return nil
            if (normalizedCategory) {
                [normalizedCategories addObject:normalizedCategory];
            }
        }
    }

    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithSet:normalizedCategories]];

    UNAuthorizationOptions normalizedOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay);
    normalizedOptions &= options;


    if (normalizedOptions != UNAuthorizationOptionNone) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:normalizedOptions
                                                                            completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                                UA_LDEBUG(@"Registering for user notification options %ld.", (unsigned long)[UAirship push].notificationOptions);

                                                                                [[UIApplication sharedApplication] registerForRemoteNotifications];
                                                                                completionHandler();
                                                                            }];
    } else {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                // Return early so we dont trigger the user to accept notifications
                completionHandler();
                return;
            }

            [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionNone
                                                                                completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                                    UA_LDEBUG(@"Unregistered for user notification options");
                                                                                    completionHandler();
                                                                                }];
        }];
    }
}

@end

