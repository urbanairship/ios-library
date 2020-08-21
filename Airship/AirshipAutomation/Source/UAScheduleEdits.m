/* Copyright Airship and Contributors */

#import "UAScheduleEdits+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessage+Internal.h"
#import "UAScheduleAudience.h"
#import "UASchedule+Internal.h"

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

- (instancetype)initWithData:(NSString *)data
                        type:(NSNumber *)type
                     builder:(UAScheduleEditsBuilder *)builder {
    self = [super init];
    if (self) {
        _data = data;
        _type = type;
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

    return [[UAScheduleEdits alloc] initWithData:[NSJSONSerialization stringWithObject:[message toJSON]]
                                 type:@(UAScheduleTypeInAppMessage)
                              builder:builder];
}

+ (instancetype)editsWithActions:(NSDictionary *)actions
                    builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:[NSJSONSerialization stringWithObject:actions]
                                 type:@(UAScheduleTypeActions)
                              builder:builder];
}

+ (instancetype)editsWithDeferredData:(UAScheduleDeferredData *)deferred
                         builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock {
    UAScheduleEditsBuilder *builder = [[UAScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleEdits alloc] initWithData:[NSJSONSerialization stringWithObject:[deferred toJSON]]
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
            "Audience: %@",
            self.data,
            self.type,
            self.priority,
            self.limit,
            self.start,
            self.end,
            self.editGracePeriod,
            self.interval,
            self.metadata,
            self.audience];
}

@end


