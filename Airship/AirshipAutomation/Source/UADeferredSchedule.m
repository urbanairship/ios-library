/* Copyright Airship and Contributors */

#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"


#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
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
