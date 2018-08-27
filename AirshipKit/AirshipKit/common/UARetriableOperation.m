/* Copyright 2018 Urban Airship and Contributors */

#import "UARetriableOperation+Internal.h"

@interface UARetriableOperation ()
@property (nonatomic, strong) UARetriable *retriable;
@property (nonatomic, strong) UADelay *delay;
@end

@implementation UARetriableOperation

+ (instancetype)operationWithRetriable:(UARetriable *)retriable {
    return [[self alloc] initWithRetriable:retriable];
}

- (instancetype)initWithRetriable:(UARetriable *)retriable {
    self = [super init];

    if (self) {
        self.retriable = retriable;
    }

    return self;
}

- (void)executeRetriableWithDelayInterval:(NSTimeInterval)delayInterval {
    @synchronized (self) {
        if (self.isCancelled) {
            [self finish];
            return;
        }

        if (delayInterval) {
            self.delay = [UADelay delayWithSeconds:delayInterval];
            [self.delay start];

            if (self.isCancelled) {
                [self finish];
                return;
            }
        }
    }

    UARetriableCompletionHandler handler = ^(UARetriableResult result) {
        if (result == UARetriableResultRetry) {
            NSTimeInterval nextDelayInterval = delayInterval == 0 ? self.retriable.minBackoffInterval : MAX(delayInterval * 2, self.retriable.maxBackoffInterval);
            [self executeRetriableWithDelayInterval:nextDelayInterval];
        } else if (result == UARetriableResultCancel) {
            [self cancel];
            [self finish];
        } else {
            [self finish];
        }

        if (self.retriable.resultHandler) {
            self.retriable.resultHandler(result);
        }
    };

    self.retriable.runBlock(handler);
}


- (void)startAsyncOperation {
    [self executeRetriableWithDelayInterval:0];
}

- (void)cancel {
    [super cancel];
    @synchronized (self) {
        if (self.delay) {
            [self.delay cancel];
        }
    }
}

@end
