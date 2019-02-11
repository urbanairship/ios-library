/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAAppForegroundEvent+Internal.h"
#import "UAEvent+Internal.h"

@implementation UAAppForegroundEvent

- (NSMutableDictionary *)gatherData:(UAUserData *)userData {
    NSMutableDictionary *data = [super gatherData:userData];
    [data removeObjectForKey:@"foreground"];
    return data;
}

- (NSString *)eventType {
    return @"app_foreground";
}

@end
