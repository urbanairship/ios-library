/* Copyright Airship and Contributors */

#import "UADeferredScheduleRetryRules+Internal.h"

@interface UADeferredScheduleRetryRules()

@property (nonatomic, copy, nullable) NSString *location;
@property (nonatomic) NSTimeInterval retryTime;

@end

@implementation UADeferredScheduleRetryRules

- (instancetype)initWithLocation:(nullable NSString *)location retryTime:(NSTimeInterval )retryTime {
    self = [super init];
    if (self) {
        self.location = location;
        self.retryTime = retryTime;
    }
    return self;
}

+ (instancetype)rulesWithLocation:(nullable NSString *)location
                    retryTime:(NSTimeInterval)retryTime {
    return [[self alloc] initWithLocation:location retryTime:retryTime];
}

@end
