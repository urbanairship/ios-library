/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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
#import <UserNotifications/UserNotifications.h>

@interface UANotificationContent()
@property (nonatomic, copy, nullable) NSString *alertTitle;
@property (nonatomic, copy, nullable) NSString *alertBody;
@property (nonatomic, copy, nullable) NSString *sound;
@property (nonatomic, assign, nullable) NSNumber *badge;
@property (nonatomic, strong, nullable) NSNumber *contentAvailable;
@property (nonatomic, copy, nullable) NSString *categoryIdentifier;
@property (nonatomic, copy, nullable) NSString *launchImage;
@property (nonatomic, copy, nonnull) NSDictionary *notificationInfo;
@property (nonatomic, strong, nullable) UNNotification *notification;
@end

@implementation UANotificationContent

- (instancetype)initWithNotificationInfo:(nonnull NSDictionary *)notificationInfo {
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

                    // Alert Title
                    self.alertTitle = alert[@"title"];

                    // Alert Body
                    self.alertBody = alert[@"body"];

                    // Launch Image
                    self.launchImage = alert[@"launch-image"];
                }
            }

            // Badge
            self.badge = apsDict[@"badge"];

            // Sound
            self.sound = apsDict[@"sound"];

            // Category
            self.categoryIdentifier = apsDict[@"category"];
        }

        // Original notification
        self.notificationInfo = notificationInfo;
    }

    return self;
}


- (instancetype)initWithUNNotification:(UNNotification *)notification {
    self = [super init];
    if (self) {
        self.alertBody = notification.request.content.body;
        self.alertTitle = notification.request.content.title;
        self.badge = notification.request.content.badge;
        self.categoryIdentifier = notification.request.content.categoryIdentifier;
        self.notificationInfo = notification.request.content.userInfo;
        self.notification = notification;


        NSDictionary *apsDict = [self.notificationInfo objectForKey:@"aps"];
        if (apsDict) {
            // Sound
            self.sound = apsDict[@"sound"];
        }
    }
    
    return self;
}

+ (instancetype)notificationWithNotificationInfo:(nonnull NSDictionary *)notificationInfo {
    return [[UANotificationContent alloc] initWithNotificationInfo:notificationInfo];
}

+ (instancetype)notificationWithUNNotification:(UNNotification *)notification {
    UANotificationContent *notificationContent = [[UANotificationContent alloc] initWithUNNotification:notification];
    return notificationContent;
}

-(NSDictionary *)localizationKeys {
    if (self.notificationInfo[@"aps"] && self.notificationInfo[@"aps"][@"alert"]) {

        // Alert
        id alert = self.notificationInfo[@"aps"][@"alert"];
        if ([alert isKindOfClass:[NSDictionary class]]) {
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
            return [localizationKeys copy];
        }
    }

    return nil;
}

- (NSString *)description {
    return [self.notificationInfo description];
}

@end
