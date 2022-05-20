/* Copyright Airship and Contributors */

#import "UAScheduleData+Internal.h"
#import "UAScheduleTriggerData+Internal.h"
#import "UAGlobal.h"

// Data version - for migration
NSUInteger const UAScheduleDataVersion = 3;

@interface UAScheduleData()
@property (nullable, nonatomic, strong) NSDate *executionStateChangeDate;
@end

@implementation UAScheduleData
@dynamic dataVersion;
@dynamic identifier;
@dynamic group;
@dynamic limit;
@dynamic triggeredCount;
@dynamic metadata;
@dynamic data;
@dynamic type;
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
@dynamic triggerContext;
@dynamic audience;
@dynamic campaigns;
@dynamic reportingContext;
@dynamic frequencyConstraintIDs;

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

- (BOOL)checkState:(UAScheduleState)state {
    return [self.executionState unsignedIntegerValue] == state;
}

- (BOOL)verifyState:(UAScheduleState)state {
    if (![self checkState:state]) {
        UA_LTRACE(@"Schedule %@ in invalid state. Expected %ld, actual %@", self.identifier, (long)state, self.executionState);
        return NO;
    } else {
        return YES;
    }
}

- (void)updateState:(UAScheduleState)state {
    UA_LTRACE(@"Updating schedule %@ state from %@ to %ld", self.identifier, self.executionState, (long) state);
    self.executionState = @(state);
}

@end
