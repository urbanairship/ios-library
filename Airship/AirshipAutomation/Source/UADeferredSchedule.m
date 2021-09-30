/* Copyright Airship and Contributors */

#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"


#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
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
    return [UAJSONUtils stringWithObject:[self.deferredData toJSON]];
}

@end
