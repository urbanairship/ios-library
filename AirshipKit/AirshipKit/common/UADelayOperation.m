/* Copyright Urban Airship and Contributors */

#import "UADelayOperation+Internal.h"

@interface UADelayOperation()
@property (nonatomic, strong) UADelay *delay;
@end

@implementation UADelayOperation

- (instancetype)initWithDelay:(UADelay *)delay {
    self = [super init];
    if (self) {
        self.delay = delay;
        __weak UADelayOperation *_self = self;
        [self addExecutionBlock:^{
            [_self.delay start];
        }];
    }

    return self;
}

- (void)cancel {
    [self.delay cancel];
    [super cancel];
}

- (NSTimeInterval)seconds {
    return self.delay.seconds;
}

+ (instancetype)operationWithDelay:(UADelay *)delay {
    return [[UADelayOperation alloc] initWithDelay:delay];
}

+ (instancetype)operationWithDelayInSeconds:(NSTimeInterval)seconds {
    return [[UADelayOperation alloc] initWithDelay:[UADelay delayWithSeconds:seconds]];
}


@end

