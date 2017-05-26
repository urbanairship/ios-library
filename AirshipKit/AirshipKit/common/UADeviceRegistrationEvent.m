/* Copyright 2017 Urban Airship and Contributors */

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAPush.h"
#import "UAUser.h"
#import "UAirship.h"

@implementation UADeviceRegistrationEvent

+ (instancetype)event {
    UADeviceRegistrationEvent *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    if ([UAirship push].pushTokenRegistrationEnabled) {
        [data setValue:[UAirship push].deviceToken forKey:@"device_token"];
    }

    [data setValue:[UAirship push].channelID forKey:@"channel_id"];
    [data setValue:[UAirship inboxUser].username forKey:@"user_id"];

    event.data = [data mutableCopy];
    return event;
}

- (NSString *)eventType {
    return @"device_registration";
}

@end
