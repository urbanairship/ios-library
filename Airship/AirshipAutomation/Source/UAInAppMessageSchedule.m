/* Copyright Airship and Contributors */

#import "UAInAppMessageSchedule.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
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
