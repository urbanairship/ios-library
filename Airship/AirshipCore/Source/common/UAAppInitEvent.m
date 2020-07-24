/* Copyright Airship and Contributors */

#import "UAAppInitEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUtils+Internal.h"
#import "UAAppStateTracker.h"

@implementation UAAppInitEvent

+ (instancetype)event {
    UAAppInitEvent *event = [[self alloc] init];
    event.eventData = [event gatherData];
    return event;
}

- (NSMutableDictionary *)gatherData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    UAAnalytics *analytics = [UAirship analytics];

    [data setValue:analytics.conversionSendID forKey:@"push_id"];
    [data setValue:analytics.conversionPushMetadata forKey:@"metadata"];
    [data setValue:[UAUtils carrierName] forKey:@"carrier"];
    [data setValue:[UAUtils connectionType] forKey:@"connection_type"];

    [data setValue:[self notificationTypes] forKey:@"notification_types"];
    [data setValue:[self notificationAuthorization] forKey:@"notification_authorization"];

    NSTimeZone *localtz = [NSTimeZone defaultTimeZone];
    [data setValue:[NSNumber numberWithDouble:[localtz secondsFromGMT]] forKey:@"time_zone"];
    [data setValue:([localtz isDaylightSavingTime] ? @"true" : @"false") forKey:@"daylight_savings"];

    // Component Versions
    [data setValue:[[UIDevice currentDevice] systemVersion] forKey:@"os_version"];
    [data setValue:[UAirshipVersion get] forKey:@"lib_version"];

    NSString *packageVersion = [UAUtils bundleVersionString] ?: @"";
    [data setValue:packageVersion forKey:@"package_version"];

    // Foreground
    BOOL isInForeground = [UAAppStateTracker shared].state != UAApplicationStateBackground;
    [data setValue:(isInForeground ? @"true" : @"false") forKey:@"foreground"];

    return data;
}

- (NSString *)eventType {
    return @"app_init";
}

@end
