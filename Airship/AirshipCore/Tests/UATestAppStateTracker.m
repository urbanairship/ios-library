/* Copyright Airship and Contributors */

#import "UATestAppStateTracker+Internal.h"

@implementation UATestAppStateTracker

static UATestAppStateTracker *shared_;

+ (void)load {
    shared_ = [[UATestAppStateTracker alloc] init];
}

-(UAApplicationState)state {
    return self.currentState;
}

+ (instancetype)shared {
    return shared_;
}

@end
