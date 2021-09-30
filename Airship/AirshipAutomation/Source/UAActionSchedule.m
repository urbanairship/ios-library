/* Copyright Airship and Contributors */

#import "UAActionSchedule.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


@implementation UAActionSchedule

+ (instancetype)scheduleWithActions:(NSDictionary *)actions
                       builderBlock:(void(^)(UAScheduleBuilder *builder))builderBlock {
    UAScheduleBuilder *builder = [[UAScheduleBuilder alloc] init];
    builderBlock(builder);
    return [[self alloc] initWithData:actions
                                 type:UAScheduleTypeActions
                              builder:builder];
}

- (NSDictionary *)actions {
    return self.data;
}

- (NSString *)dataJSONString {
    return [UAJSONUtils stringWithObject:self.data];
}

@end
