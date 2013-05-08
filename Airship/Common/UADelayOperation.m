
#import "UADelayOperation.h"

@interface UADelayOperation()
@property(nonatomic, assign) NSInteger seconds;
@end

@implementation UADelayOperation

- (id)initWithDelayInSeconds:(NSInteger)seconds {
    if (self = [super init]) {
        [self addExecutionBlock:^{
            sleep(seconds);
        }];

        self.seconds = seconds;
    }

    return self;
}

+ (id)operationWithDelayInSeconds:(NSInteger)seconds {
    return [[[UADelayOperation alloc] initWithDelayInSeconds:seconds] autorelease];
}

@end
