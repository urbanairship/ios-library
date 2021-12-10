/* Copyright Airship and Contributors */

#import "UASchedule+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSUInteger const UAScheduleMaxTriggers = 10;

@implementation UAScheduleBuilder

- (instancetype)init {
    self = [super init];
    if (self) {
        self.limit = 1;
    }

    return self;
}

@end

@interface UASchedule()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, assign) NSInteger priority;
@property(nonatomic, copy) NSArray *triggers;
@property(nonatomic, assign) NSUInteger limit;
@property(nonatomic, strong) NSDate *start;
@property(nonatomic, strong) NSDate *end;
@property(nonatomic, strong) UAScheduleDelay *delay;
@property(nonatomic, copy) NSString *group;
@property(nonatomic, assign) NSTimeInterval interval;
@property(nonatomic, assign) NSTimeInterval editGracePeriod;
@property(nonatomic, copy) NSDictionary *metadata;
@property(nonatomic, strong) UAScheduleAudience *audience;
@end

@implementation UASchedule

@synthesize data = _data;
@synthesize type = _type;
@synthesize campaigns = _campaigns;
@synthesize reportingContext = _reportingContext;

@synthesize frequencyConstraintIDs = _frequencyConstraintIDs;

- (BOOL)isValid {
    if (!self.triggers.count || self.triggers.count > UAScheduleMaxTriggers) {
        return NO;
    }

    if ([self.start compare:self.end] == NSOrderedDescending) {
        return NO;
    }

    if (self.delay && !self.delay.isValid) {
        return NO;
    }

    return YES;
}

- (instancetype)initWithData:(id)data
                        type:(UAScheduleType)scheduleType
                     builder:(UAScheduleBuilder *)builder {
    self = [super init];
    if (self) {
        _data = data;
        _type = scheduleType;
        self.identifier = builder.identifier ?: [NSUUID UUID].UUIDString;
        self.priority = builder.priority;
        self.triggers = builder.triggers ?: @[];
        
        self.limit = builder.limit;
        self.group = builder.group;
        self.delay = builder.delay;
        self.start = builder.start ?: [NSDate distantPast];
        self.end = builder.end ?: [NSDate distantFuture];
        self.editGracePeriod = builder.editGracePeriod;
        self.interval = builder.interval;
        self.metadata = builder.metadata ?: @{};
        self.audience = builder.audience;
        _campaigns = [builder.campaigns copy] ?: @{};
        _reportingContext = [builder.reportingContext copy] ?: @{};
        _frequencyConstraintIDs = [builder.frequencyConstraintIDs copy] ?: @[];
    }

    return self;
}

- (BOOL)isEqualToSchedule:(UASchedule *)schedule {
    if (!schedule) {
        return NO;
    }

    if (![self.identifier isEqualToString:schedule.identifier]) {
        return NO;
    }

    if (![self.metadata isEqualToDictionary:schedule.metadata]) {
        return NO;
    }

    if (self.type != schedule.type) {
        return NO;
    }

    if (self.priority != schedule.priority) {
        return NO;
    }

    if (self.limit != schedule.limit) {
        return NO;
    }

    if (self.interval != schedule.interval) {
        return NO;
    }

    if (self.editGracePeriod != schedule.editGracePeriod) {
        return NO;
    }

    if (![self.start isEqualToDate:schedule.start]) {
        return NO;
    }

    if (![self.end isEqualToDate:schedule.end]) {
        return NO;
    }

    if (![self.data isEqual:schedule.data]) {
        return NO;
    }

    if (self.triggers != schedule.triggers && ![self.triggers isEqualToArray:schedule.triggers]) {
        return NO;
    }

    if (self.group != schedule.group && ![self.group isEqualToString:schedule.group]) {
        return NO;
    }

    if (self.delay != schedule.delay && ![self.delay isEqualToDelay:schedule.delay]) {
        return NO;
    }

    if (self.audience != schedule.audience && ![self.audience isEqual:schedule.audience]) {
        return NO;
    }

    if (self.campaigns != schedule.campaigns && ![self.campaigns isEqual:schedule.campaigns]) {
        return NO;
    }
    
    if (self.reportingContext != schedule.reportingContext && ![self.reportingContext isEqual:schedule.reportingContext]) {
        return NO;
    }

    if (self.frequencyConstraintIDs != schedule.frequencyConstraintIDs && ![self.frequencyConstraintIDs isEqual:schedule.frequencyConstraintIDs]) {
        return NO;
    }

    return YES;
}


#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UASchedule class]]) {
        return NO;
    }

    return [self isEqualToSchedule:(UASchedule *)object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.identifier hash];
    result = 31 * result + [self.metadata hash];
    result = 31 * result + [self.start hash];
    result = 31 * result + [self.end hash];
    result = 31 * result + [self.group hash];
    result = 31 * result + [self.triggers hash];
    result = 31 * result + [self.data hash];
    result = 31 * result + [self.delay hash];
    result = 31 * result + [self.audience hash];
    result = 31 * result + [self.campaigns hash];
    result = 31 * result + [self.reportingContext hash];
    result = 31 * result + [self.frequencyConstraintIDs hash];
    result = 31 * result + self.editGracePeriod;
    result = 31 * result + self.interval;
    result = 31 * result + self.type;
    result = 31 * result + self.limit;
    result = 31 * result + self.priority;
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UASchedule %@", self.identifier];
}

@end

