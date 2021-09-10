/* Copyright Airship and Contributors */

#import "UAActionSchedule.h"
#import "UASchedule+Internal.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
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
