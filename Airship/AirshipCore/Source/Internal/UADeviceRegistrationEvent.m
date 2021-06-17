/* Copyright Airship and Contributors */

#import "UADeviceRegistrationEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAPush.h"
#import "UAChannel.h"
#import "UAirship.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation UADeviceRegistrationEvent

+ (instancetype)event {
    UADeviceRegistrationEvent *event = [[self alloc] init];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    if ([[UAirship shared].privacyManager isEnabled:UAFeaturesPush]) {
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
