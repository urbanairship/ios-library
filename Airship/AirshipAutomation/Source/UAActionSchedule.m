/* Copyright Airship and Contributors */

#import "UAActionSchedule.h"
#import "UASchedule+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

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
    return [NSJSONSerialization stringWithObject:self.data];
}

@end
