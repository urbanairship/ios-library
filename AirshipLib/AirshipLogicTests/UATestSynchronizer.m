
#import "UATestSynchronizer.h"

@implementation UATestSynchronizer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
        //default to 0.1 seconds per run loop spin
        self.runLoopInterval = 0.1;
        //default to a 2 second timeout
        self.defaultTimeoutInterval = 2;
    }
    return self;
}

- (id)valueForKey:(NSString *)key {
    return [super valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    return [super valueForKeyPath:keyPath];
}

- (BOOL)waitWithTimeoutInterval:(NSTimeInterval)interval {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    while (dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_NOW)  && [timeoutDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:self.runLoopInterval]];
    }
    return [timeoutDate timeIntervalSinceNow] > 0;
}

- (BOOL)wait {
    return [self waitWithTimeoutInterval:self.defaultTimeoutInterval];
}

- (void)continue {
    dispatch_semaphore_signal(self.semaphore);
}

@end
