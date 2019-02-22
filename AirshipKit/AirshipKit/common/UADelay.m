/* Copyright Urban Airship and Contributors */

#import "UADelay+Internal.h"

@interface UADelay()
@property (nonatomic, assign) NSTimeInterval seconds;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;    // GCD objects use ARC
@end

@implementation UADelay

- (instancetype)initWithDelayInSeconds:(NSTimeInterval)seconds {
    self = [super init];
    if (self) {
        self.seconds = seconds;
        self.semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

+ (instancetype)delayWithSeconds:(NSTimeInterval)seconds {
    return [[UADelay alloc] initWithDelayInSeconds:seconds];
}

- (void)cancel {
    dispatch_semaphore_signal(self.semaphore);
}

- (void)start {
    //dispatch time is calculated as nanoseconds delta offset
    dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, (self.seconds * NSEC_PER_SEC)));
}

@end
