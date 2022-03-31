/* Copyright Airship and Contributors */

#import "UADeferredAPIClientResponse+Internal.h"

@implementation UADeferredAPIClientResponse

- (instancetype)initWithStatus:(NSInteger)status result:(UADeferredScheduleResult *)result rules:(UADeferredScheduleRetryRules *)rules {
    self = [super init];
    if (self) {
        self.status = status;
        self.result = result;
        self.rules = rules;
    }
    return self;
}

+ (instancetype)responseWithStatus:(NSInteger)status
                            result:(nullable UADeferredScheduleResult *)result
                             rules:(nullable UADeferredScheduleRetryRules *)rules {
    return [[self alloc] initWithStatus:status result:result rules:rules];
}

@end
