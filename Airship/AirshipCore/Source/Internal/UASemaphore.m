/* Copyright Airship and Contributors */

#import "UASemaphore.h"

@interface UASemaphore ()
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation UASemaphore

- (instancetype)init {
    self = [super init];

    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
    }

    return self;
}

+ (instancetype)semaphore {
    return [[self alloc] init];
}

- (void)wait {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
}

- (BOOL)wait:(NSTimeInterval)timeout {
    return dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC)) == 0;
}

- (BOOL)signal {
    return dispatch_semaphore_signal(self.semaphore) != 0;
}

@end
