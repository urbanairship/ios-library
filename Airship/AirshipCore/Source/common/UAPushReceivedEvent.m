/* Copyright Airship and Contributors */

#import "UAPushReceivedEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics+Internal.h"

@implementation UAPushReceivedEvent

+ (instancetype)eventWithNotification:(NSDictionary *)notification {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:[notification objectForKey:kUAPushMetadata] forKey:@"metadata"];
    [data setValue:[notification objectForKey:@"_"] ?: kUAMissingSendID forKey:@"push_id"];

    UAPushReceivedEvent *event = [[self alloc] init];
    event.data = data;
    return event;
}

- (NSString *)eventType {
    return @"push_received";
}

@end
