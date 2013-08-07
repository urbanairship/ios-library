
#import "UADelayOperation.h"

@interface UADelayOperation()
@property(nonatomic, assign) NSInteger seconds;
@property(nonatomic, assign) dispatch_semaphore_t semaphore;
@end

@implementation UADelayOperation

- (id)initWithDelayInSeconds:(NSInteger)seconds {
    self = [super init];
    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
        __block UADelayOperation *_self = self;

        [self addExecutionBlock:^{
            //dispatch time is calculated as nanoseconds delta offset
            dispatch_semaphore_wait(_self.semaphore, dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC));
        }];

        self.seconds = seconds;
    }

    return self;
}

- (void)cancel {
    [super cancel];
    dispatch_semaphore_signal(self.semaphore);
}

- (void)dealloc {
    dispatch_release(self.semaphore);
    [super dealloc];
}

+ (id)operationWithDelayInSeconds:(NSInteger)seconds {
    return [[[UADelayOperation alloc] initWithDelayInSeconds:seconds] autorelease];
}

@end
