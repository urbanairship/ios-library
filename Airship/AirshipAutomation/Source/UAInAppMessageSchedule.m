/* Copyright Airship and Contributors */

#import "UAInAppMessageSchedule.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@implementation UAInAppMessageSchedule

+ (instancetype)scheduleWithMessage:(UAInAppMessage *)message
                       builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock {
    UAScheduleBuilder *builder = [[UAScheduleBuilder alloc] init];
    builderBlock(builder);
    return [[self alloc] initWithData:message
                                 type:UAScheduleTypeInAppMessage
                              builder:builder];
}

- (UAInAppMessage *)message {
    return self.data;
}

- (NSString *)dataJSONString {
    return [UAJSONUtils stringWithObject:[self.data toJSON]];
}

@end
