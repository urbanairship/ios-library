/* Copyright Airship and Contributors */

#import "UAScheduleEdits+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleAudience.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@implementation UAScheduleEditsBuilder

@end

@interface UAScheduleEdits ()
@property(nonatomic, strong, nullable) NSNumber *priority;
@property(nonatomic, strong, nullable) NSNumber *limit;
@property(nonatomic, strong, nullable) NSDate *start;
@property(nonatomic, strong, nullable) NSDate *end;
@property(nonatomic, strong, nullable) NSNumber *editGracePeriod;
@property(nonatomic, strong, nullable) NSNumber *interval;
@property(nonatomic, copy, nullable) NSDictionary *metadata;
@property(nonatomic, strong, nullable) UAScheduleAudience *audience;
@end

@implementation UAScheduleEdits

@synthesize data = _data;
@synthesize type = _type;
@synthesize campaigns = _campaigns;
@synthesize reportingContext = _reportingContext;
@synthesize frequencyConstraintIDs = _frequencyConstraintIDs;

- (instancetype)initWithData:(NSString *)data
                        type:(NSNumber *)type
                     builder:(UAScheduleEditsBuilder *)builder {
    self = [super init];
    if (self) {
        _data = data;
        _type = type;
        _campaigns = builder.campaigns;
        _reportingContext = builder.reportingContext;
        _frequencyConstraintIDs = builder.frequencyConstraintIDs;
        self.priority = builder.priority;
        self.limit = builder.limit;
        self.start = builder.start;
        self.end = builder.end;
        self.editGracePeriod = builder.editGracePeriod;
        self.interval = builder.interval;
        self.metadata = builder.metadata;
        self.audience = builder.audience;
    }

    return self;
}

+ (instancetype)editsWithMessage:(UAInAppMessage *)message
                    builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:[UAJSONUtils stringWithObject:[message toJSON]]
                                 type:@(UAScheduleTypeInAppMessage)
                              builder:builder];
}

+ (instancetype)editsWithActions:(NSDictionary *)actions
                    builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:[UAJSONUtils stringWithObject:actions]
                                 type:@(UAScheduleTypeActions)
                              builder:builder];
}

+ (instancetype)editsWithDeferredData:(UAScheduleDeferredData *)deferred
                         builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:[UAJSONUtils stringWithObject:[deferred toJSON]]
                                 type:@(UAScheduleTypeDeferred)
                              builder:builder];
}

+ (instancetype)editsWithBuilderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:nil type:nil builder:builder];
}


- (NSString *)description {
    return [NSString stringWithFormat:@"Data: %@\n"
            "Type: %@\n"
            "Priority: %@\n"
            "Limit: %@\n"
            "Start: %@\n"
            "End: %@\n"
            "Edit Grace Period: %@\n"
            "Interval: %@\n"
            "Metadata: %@\n"
            "Audience: %@\n"
            "Campaigns: %@\n"
            "Reporting Context: %@\n"
            "Frequency Constraint IDs: %@",
            self.data,
            self.type,
            self.priority,
            self.limit,
            self.start,
            self.end,
            self.editGracePeriod,
            self.interval,
            self.metadata,
            self.audience,
            self.campaigns,
            self.reportingContext,
            self.frequencyConstraintIDs];
}

@end


