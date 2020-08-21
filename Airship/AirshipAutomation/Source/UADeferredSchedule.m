/* Copyright Airship and Contributors */

#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

@implementation UADeferredSchedule


+ (instancetype)scheduleWithDeferredData:(UAScheduleDeferredData *)deferredData
                            builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock {
    UAScheduleBuilder *builder = [[UAScheduleBuilder alloc] init];
    builderBlock(builder);
    return [[self alloc] initWithData:deferredData
                                 type:UAScheduleTypeDeferred
                              builder:builder];
}

-(UAScheduleDeferredData *)deferredData {
    return self.data;
}

- (NSString *)dataJSONString {
    return [NSJSONSerialization stringWithObject:[self.deferredData toJSON]];
}

@end
