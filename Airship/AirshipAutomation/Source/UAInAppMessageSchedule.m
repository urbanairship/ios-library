/* Copyright Airship and Contributors */

#import "UAInAppMessageSchedule.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

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
    return [NSJSONSerialization stringWithObject:[self.data toJSON]];
}

@end
