/* Copyright Airship and Contributors */

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAPush.h"
#import "UAChannel.h"
#import "UAirship.h"

@implementation UADeviceRegistrationEvent

+ (instancetype)event {
    UADeviceRegistrationEvent *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    if ([UAirship push].pushTokenRegistrationEnabled) {
        [data setValue:[UAirship push].deviceToken forKey:@"device_token"];
    }

    [data setValue:[UAirship channel].identifier forKey:@"channel_id"];

    event.eventData = data;
    return event;
}

- (NSString *)eventType {
    return @"device_registration";
}

@end
