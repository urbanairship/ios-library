/* Copyright Airship and Contributors */

#import "UARetriablePipeline+Internal.h"
#import "UAAsyncOperation+Internal.h"
#import "UAAirshipAutomationCoreImport.h"


#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif
@interface UARetriableChain : NSObject
@property (nonatomic, strong) NSMutableArray *retriables;
@end

@implementation UARetriableChain
@end

@interface UARetriablePipeline ()
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) UADispatcher *dispatcher;
@end

@implementation UARetriablePipeline

- (instancetype)initWithQueue:(NSOperationQueue *)queue dispatcher:(UADispatcher *)dispatcher {
    self = [super init];

    if (self) {
        self.queue = queue;
        self.dispatcher = dispatcher;
    }

    return self;
}

+ (instancetype)pipelineWithQueue:(NSOperationQueue *)queue dispatcher:(UADispatcher *)dispatcher {
    return [[self alloc] initWithQueue:queue dispatcher:dispatcher];
}

+ (instancetype)pipeline {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    return [self pipelineWithQueue:queue dispatcher:UADispatcher.global];
}

- (void)addRetriable:(UARetriable *)retriable {
    [self addChainedRetriables:@[retriable]];
}

- (void)addChainedRetriables:(NSArray<UARetriable *> *)retriables {
    UARetriableChain *chain = [[UARetriableChain alloc] init];
    chain.retriables = [retriables mutableCopy];
    [self executeChain:chain backoff:0];
}

- (void)executeChain:(UARetriableChain *)chain backoff:(NSTimeInterval)backoff {
    if (!chain.retriables.count) {
        return;
    }

    UA_WEAKIFY(self)
    UARetriable *next = [chain.retriables firstObject];
    NSTimeInterval nextBackoff = backoff == 0 ? next.minBackoffInterval : MIN(backoff * 2, next.maxBackoffInterval);

    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        UARetriableCompletionHandler handler = ^(UARetriableResult result) {
            UA_STRONGIFY(self)
            switch(result) {
                case UARetriableResultRetry:
                    [self scheduleRetryWithBackoff:nextBackoff chain:chain];
                    break;
                case UARetriableResultSuccess:
                    [chain.retriables removeObjectAtIndex:0];
                    [self executeChain:chain backoff:0];
                    break;
                case UARetriableResultCancel:
                    break;
                case UARetriableResultInvalidate:
                    break;
            }

            if (next.resultHandler) {
                next.resultHandler(result);
            }

            [operation finish];
        };

        next.runBlock(handler);
    }];

    [self.queue addOperation:operation];
}

- (void)scheduleRetryWithBackoff:(NSTimeInterval)backoff chain:(UARetriableChain *)chain {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAfter:backoff block:^{
        UA_STRONGIFY(self)
        [self executeChain:chain backoff:backoff];
    }];
}

@end
