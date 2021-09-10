/* Copyright Airship and Contributors */

#import "UADeferredSchedule+Internal.h"
#import "UASchedule+Internal.h"


#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
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
