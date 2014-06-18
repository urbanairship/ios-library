/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#import "UAEvent+Internal.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "UA_Reachability.h"
#import "UAPush.h"
#import "UAInboxUtils.h"

@implementation UAEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        self.eventId = [[NSUUID UUID] UUIDString];
        self.time = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
        return self;
    }
    return nil;
}

- (BOOL)isValid {
    return YES;
}

- (NSString *)eventType {
    return @"base";
}


- (NSUInteger)estimatedSize {
    NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionary];
    [eventDictionary setValue:self.eventType forKey:@"type"];
    [eventDictionary setValue:self.time forKey:@"time"];
    [eventDictionary setValue:self.eventId forKey:@"event_id"];
    [eventDictionary setValue:self.data forKey:@"data"];
    

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:eventDictionary
                                                        options:0
                                                          error:nil];
    
    UA_LDEBUG(@"Estimated event size: %lu", (unsigned long)[jsonData length]);
    
    return [jsonData length];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAEvent id=%@, type=%@, time=%@, data=%@",
            self.eventId, self.eventType, self.time, self.data];
}

- (NSString *)connectionType {
    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    NSString *connectionTypeString = @"";
    switch (netStatus) {
        case UA_NotReachable:
        {
            connectionTypeString = @"none";//this should never be sent
            break;
        }
        case UA_ReachableViaWWAN:
        {
            connectionTypeString = @"cell";
            break;
        }
        case UA_ReachableViaWiFi:
        {
            connectionTypeString = @"wifi";
            break;
        }
    }
    return connectionTypeString;
}

- (NSString *)carrierName {
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    return netInfo.subscriberCellularProvider.carrierName;
}

- (NSArray *)notificationTypes {
    NSMutableArray *notificationTypes = [NSMutableArray array];
    UIRemoteNotificationType enabledRemoteNotificationTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];

    if ((UIRemoteNotificationTypeBadge & enabledRemoteNotificationTypes) > 0) {
        [notificationTypes addObject:@"badge"];
    }

    if ((UIRemoteNotificationTypeSound & enabledRemoteNotificationTypes) > 0) {
        [notificationTypes addObject:@"sound"];
    }

    if ((UIRemoteNotificationTypeAlert & enabledRemoteNotificationTypes) > 0) {
        [notificationTypes addObject:@"alert"];
    }

    if ((UIRemoteNotificationTypeNewsstandContentAvailability & enabledRemoteNotificationTypes) > 0) {
        [notificationTypes addObject:@"newsstand"];
    }

    return notificationTypes;
}

@end

@interface UAEventAppInit()
- (NSMutableDictionary *)gatherData;
@end

@implementation UAEventAppInit

+ (instancetype)event {
    UAEventAppInit *event = [[self alloc] init];
    event.data = [[event gatherData] mutableCopy];
    return event;
}

- (NSMutableDictionary *)gatherData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    UAAnalytics *analytics = [UAirship shared].analytics;

    [data setValue:analytics.conversionPushId forKey:@"push_id"];
    [data setValue:analytics.conversionRichPushId forKey:@"rich_push_id"];

    [data setValue:[UAUser defaultUser].username forKey:@"user_id"];
    [data setValue:[self connectionType] forKey:@"connection_type"];
    [data setValue:[self carrierName] forKey:@"carrier"];
    [data setValue:[self notificationTypes] forKey:@"notification_types"];

    NSTimeZone *localtz = [NSTimeZone defaultTimeZone];
    [data setValue:[NSNumber numberWithDouble:[localtz secondsFromGMT]] forKey:@"time_zone"];
    [data setValue:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];

    // Component Versions
    [data setValue:[UAirship shared].osVersion forKey:@"os_version"];
    [data setValue:[UAirshipVersion get] forKey:@"lib_version"];
    [data setValue:[UAirship shared].packageVersion forKey:@"package_version"];

    // Foreground
    BOOL isInForeground = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground);
    [data setValue:(isInForeground ? @"true" : @"false") forKey:@"foreground"];

    return data;
}

- (NSString *)eventType {
    return @"app_init";
}

- (NSUInteger)estimatedSize {
    return kEventAppInitSize;
}

@end

@implementation UAEventAppForeground

- (NSMutableDictionary *)gatherData {
    NSMutableDictionary *data = [super gatherData];
    [data removeObjectForKey:@"foreground"];
    return data;
}

- (NSString *)eventType {
    return @"app_foreground";
}

@end

@implementation UAEventAppExit

+ (instancetype)event {
    UAEventAppExit *event = [[self alloc] init];
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    UAAnalytics *analytics = [UAirship shared].analytics;

    [data setValue:analytics.conversionPushId forKey:@"push_id"];
    [data setValue:analytics.conversionRichPushId forKey:@"rich_push_id"];


    [data setValue:[event connectionType] forKey:@"connection_type"];

    event.data = [data mutableCopy];
    return event;
}


- (NSString *)eventType {
    return @"app_exit";
}

- (NSUInteger)estimatedSize {
    return kEventAppExitSize;
}

@end

@implementation UAEventAppBackground

- (NSString *)eventType {
    return @"app_background";
}

@end

@implementation UAEventAppActive

+ (instancetype)event {
    UAEventAppActive *event = [[self alloc] init];
    event.data = @{@"class_name": @""};
    return event;
}

- (NSString *)eventType {
    return @"activity_started";
}

- (NSUInteger)estimatedSize {
    return kEventAppActiveSize;
}

@end

@implementation UAEventAppInactive

+ (instancetype)event {
    UAEventAppInactive *event = [[self alloc] init];
    event.data = @{@"class_name": @""};
    return event;
}

- (NSString *)eventType {
    return @"activity_stopped";
}

- (NSUInteger)estimatedSize {
    return kEventAppInactiveSize;
}

@end

@implementation UAEventDeviceRegistration

+ (instancetype)event {
    UAEventDeviceRegistration *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    [data setValue:[UAPush shared].deviceToken forKey:@"device_token"];
    [data setValue:[UAPush shared].channelID forKey:@"channel_id"];
    [data setValue:[UAUser defaultUser].username forKey:@"user_id"];

    event.data = [data mutableCopy];
    return event;
}

- (NSString *)eventType {
    return @"device_registration";
}

- (NSUInteger)estimatedSize {
    return kEventDeviceRegistrationSize;
}

@end

@implementation UAEventPushReceived

+ (instancetype)eventWithNotification:(NSDictionary *)notification {
    UAEventPushReceived *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    NSString *richPushId = [UAInboxUtils getRichPushMessageIDFromNotification:notification];
    if (richPushId) {
        [data setValue:richPushId forKey:@"rich_push_id"];
    }

    // Add the std push id, if present, else create a UUID
    NSString *pushId = [notification objectForKey:@"_"];
    if (pushId) {
        [data setValue:pushId forKey:@"push_id"];
    } else {
        [data setValue:[UAUtils UUID] forKey:@"push_id"];
    }

    event.data = [data mutableCopy];
    return event;
}

- (NSString *)eventType {
    return @"push_received";
}

- (NSUInteger)estimatedSize {
    return kEventPushReceivedSize;
}

@end




