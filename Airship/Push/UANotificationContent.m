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

#import "UANotificationContent.h"
#import "NSString+UALocalizationAdditions.h"

@implementation UANotificationContent

- (instancetype)initWithNotificationInfo:(NSDictionary *)notificationInfo {
    self = [super init];
    if (self) {
        NSDictionary *apsDict = [notificationInfo objectForKey:@"aps"];

        if (apsDict) {

            // Alert
            id alert = [apsDict objectForKey:@"alert"];
            if (alert) {
                if ([alert isKindOfClass:[NSString class]])  {

                    // Alert Body
                    self.alertBody = apsDict[@"alert"];

                } else if ([alert isKindOfClass:[NSDictionary class]]) {

                    NSMutableDictionary *localizationKeys = [NSMutableDictionary dictionary];

                    // Alert Title
                    self.alertTitle = alert[@"title"];

                    // Alert Body
                    self.alertBody = alert[@"body"];

                    // Launch Image
                    self.launchImage = alert[@"launch-image"];

                    // Localization Keys
                    if (alert[@"title-loc-key"]) {
                        localizationKeys[@"title-loc-key"] = alert[@"title-loc-key"];
                    }

                    if (alert[@"title-loc-args"]) {
                        localizationKeys[@"title-loc-args"] = alert[@"title-loc-args"];
                    }

                    if (alert[@"action-loc-key"]) {
                        localizationKeys[@"action-loc-key"] = alert[@"action-loc-key"];
                    }

                    if (alert[@"loc-key"]) {
                        localizationKeys[@"loc-key"] = alert[@"loc-key"];
                    }

                    if (alert[@"loc-args"]) {
                        localizationKeys[@"loc-args"] = alert[@"loc-args"];
                    }

                    // Localization Keys
                    self.localizationKeys = [NSDictionary dictionaryWithDictionary:localizationKeys];
                }
            }

            // Badge
            self.badge = apsDict[@"badge"];

            // Sound
            self.sound = apsDict[@"sound"];

            // Category
            self.categoryIdentifier = apsDict[@"category"];

            // ContentAvailable
            self.contentAvailable = apsDict[@"content-available"];
        }

        // Original notification
        self.notificationInfo = notificationInfo;
    }

    return self;
}

+ (instancetype)notificationWithNotificationInfo:(NSDictionary *)notificationInfo {
    UANotificationContent *notificationContent = [[UANotificationContent alloc] initWithNotificationInfo:notificationInfo];

    return notificationContent;
}

+ (instancetype)notificationWithUNNotification:(UNNotification *)notification {

    UANotificationContent *notificationContent = [[UANotificationContent alloc] initWithNotificationInfo:notification.request.content.userInfo];
    notificationContent.notification = notification;

    return notificationContent;
}

@end
