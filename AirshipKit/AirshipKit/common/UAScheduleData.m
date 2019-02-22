/* Copyright Urban Airship and Contributors */

#import "UAScheduleData+Internal.h"

// Data version - for migration
NSUInteger const UAScheduleDataVersion = 1;

@interface UAScheduleData()
@property (nullable, nonatomic, retain) NSDate *executionStateChangeDate;
@end

@implementation UAScheduleData

@dynamic dataVersion;
@dynamic identifier;
@dynamic group;
@dynamic limit;
@dynamic triggeredCount;
@dynamic data;
@dynamic priority;
@dynamic triggers;
@dynamic start;
@dynamic end;
@dynamic delay;
@dynamic executionState;
@dynamic delayedExecutionDate;
@dynamic executionStateChangeDate;
@dynamic interval;
@dynamic editGracePeriod;

-(void)setExecutionState:(NSNumber *)executionState {
    [self willChangeValueForKey:@"executionState"];
    [self setPrimitiveValue:executionState forKey:@"executionState"];
    [self didChangeValueForKey:@"executionState"];
    [self setExecutionStateChangeDate:[NSDate date]];
}

- (BOOL)isOverLimit {
    NSUInteger limit = [self.limit unsignedIntegerValue];
    NSUInteger count = [self.triggeredCount unsignedIntegerValue];

    return limit > 0 && count >= limit;
}

- (BOOL)isExpired {
    return [self.end compare:[NSDate date]] == NSOrderedAscending;
}

@end
