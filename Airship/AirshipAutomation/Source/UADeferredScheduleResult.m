/* Copyright Airship and Contributors */

#import "UADeferredScheduleResult+Internal.h"

@interface UADeferredScheduleResult()
@property (nonatomic, assign) BOOL isAudienceMatch;
@property (nonatomic, strong) UAInAppMessage *message;
@end

@implementation UADeferredScheduleResult

- (instancetype)initWithMessage:(nullable UAInAppMessage *)message audienceMatch:(BOOL)audienceMatch {
    self = [super init];
    if (self) {
        self.message = message;
        self.isAudienceMatch = audienceMatch;
    }
    return self;
}

+ (instancetype)resultWithMessage:(nullable UAInAppMessage *)message
                    audienceMatch:(BOOL)audienceMatch {
    return [[self alloc] initWithMessage:message audienceMatch:audienceMatch];
}
@end
