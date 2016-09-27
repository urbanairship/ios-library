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

#import <UIKit/UIKit.h>
#import "UAAppInitEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUser.h"
#import "UAUtils.h"

@implementation UAAppInitEvent

+ (instancetype)event {
    UAAppInitEvent *event = [[self alloc] init];
    event.data = [[event gatherData] mutableCopy];
    return event;
}

- (NSMutableDictionary *)gatherData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    UAAnalytics *analytics = [UAirship shared].analytics;

    [data setValue:analytics.conversionSendID forKey:@"push_id"];
    [data setValue:analytics.conversionPushMetadata forKey:@"metadata"];
    [data setValue:analytics.conversionRichPushID forKey:@"rich_push_id"];

    [data setValue:[UAirship inboxUser].username forKey:@"user_id"];

    [data setValue:[UAUtils connectionType] forKey:@"connection_type"];
    [data setValue:[self carrierName] forKey:@"carrier"];

    [data setValue:[self notificationTypes] forKey:@"notification_types"];

    NSTimeZone *localtz = [NSTimeZone defaultTimeZone];
    [data setValue:[NSNumber numberWithDouble:[localtz secondsFromGMT]] forKey:@"time_zone"];
    [data setValue:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];

    // Component Versions
    [data setValue:[[UIDevice currentDevice] systemVersion] forKey:@"os_version"];
    [data setValue:[UAirshipVersion get] forKey:@"lib_version"];

    NSString *packageVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"";
    [data setValue:packageVersion forKey:@"package_version"];

    // Foreground
    BOOL isInForeground = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground);
    [data setValue:(isInForeground ? @"true" : @"false") forKey:@"foreground"];

    return data;
}

- (NSString *)eventType {
    return @"app_init";
}

@end
