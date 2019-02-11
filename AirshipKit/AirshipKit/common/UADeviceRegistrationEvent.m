/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAPush.h"
#import "UAUserData.h"
#import "UAirship.h"

@implementation UADeviceRegistrationEvent

+ (instancetype)event {
    UADeviceRegistrationEvent *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    if ([UAirship push].pushTokenRegistrationEnabled) {
        [data setValue:[UAirship push].deviceToken forKey:@"device_token"];
    }

    [data setValue:[UAirship push].channelID forKey:@"channel_id"];

    event.data = data;

    return event;
}

+ (instancetype)event:(UAUserData *)userData {
    UADeviceRegistrationEvent *event = [self event];

#if !TARGET_OS_TV   // Inbox not supported on tvOS
    NSMutableDictionary *data = [event.data mutableCopy];
    [data setValue:userData.username forKey:@"user_id"];
    event.data = data;
#endif

    return event;
}

- (NSString *)eventType {
    return @"device_registration";
}

@end
