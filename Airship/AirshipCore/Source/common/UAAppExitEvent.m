/* Copyright Airship and Contributors */

#import "UAAppExitEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUtils+Internal.h"

@implementation UAAppExitEvent

+ (instancetype)event {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:[UAirship analytics].conversionSendID forKey:@"push_id"];
    [data setValue:[UAirship analytics].conversionPushMetadata forKey:@"metadata"];
    [data setValue:[UAUtils connectionType] forKey:@"connection_type"];

    UAAppExitEvent *event = [[self alloc] init];
    event.data = [data copy];
    return event;
}

- (NSString *)eventType {
    return @"app_exit";
}

@end
