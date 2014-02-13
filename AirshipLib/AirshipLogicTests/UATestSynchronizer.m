
#import "UATestSynchronizer.h"

@implementation UATestSynchronizer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
        //default to 0.1 seconds per run loop spin
        self.runLoopInterval = 0.1;
        //default to a 2 second timeout
        self.timeoutInterval = 2;
    }
    return self;
}

- (BOOL)wait {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:self.timeoutInterval];
    while (dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_NOW)  && [timeoutDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:self.runLoopInterval]];
    }
    return [timeoutDate timeIntervalSinceNow] > 0;
}

- (void)continue {
    dispatch_semaphore_signal(self.semaphore);
}

- (void)dealloc {
#if !OS_OBJECT_USE_OBJC
    dispatch_release(self.semaphore);
#endif
}

@end
