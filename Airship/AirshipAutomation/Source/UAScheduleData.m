/* Copyright Airship and Contributors */

#import "UAScheduleData+Internal.h"
#import "UAScheduleTriggerContextData+Internal.h"
#import "UAJSONSerialization.h"
#import "UAScheduleTriggerData+Internal.h"


// Data version - for migration
NSUInteger const UAScheduleDataVersion = 2;

@interface UAScheduleData()
@property (nullable, nonatomic, retain) NSDate *executionStateChangeDate;
@end

@implementation UAScheduleData

@dynamic dataVersion;
@dynamic identifier;
@dynamic group;
@dynamic limit;
@dynamic triggeredCount;
@dynamic metadata;
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
@dynamic triggerContext;

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


- (void)updateTriggerContext:(UAScheduleTriggerData *)trigger
                       event:(NSDictionary *)event {

    UAScheduleTriggerContextData *data = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleTriggerContextData"
                                                                                     inManagedObjectContext:self.managedObjectContext];
    data.type = trigger.type;
    data.predicateData = trigger.predicateData;
    data.goal = trigger.goal;

    if (event) {
        NSData *eventData = [UAJSONSerialization dataWithJSONObject:event options:0 error:nil];
        if (eventData) {
            data.event = [[NSString alloc] initWithData:eventData encoding:NSUTF8StringEncoding];
        }
    }

    self.triggerContext = data;
}

@end
