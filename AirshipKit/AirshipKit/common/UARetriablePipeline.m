/* Copyright 2018 Urban Airship and Contributors */

#import "UARetriablePipeline+Internal.h"
#import "UARetriableOperation+Internal.h"
#import "UAGlobal.h"

@interface UARetriablePipeline ()
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UARetriablePipeline

- (instancetype)initWithQueue:(NSOperationQueue *)queue {
    self = [super init];

    if (self) {
        self.queue = queue;
    }

    return self;
}

+ (instancetype)pipelineWithQueue:(NSOperationQueue *)queue {
    return [[self alloc] initWithQueue:queue];
}

+ (instancetype)pipeline {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    return [self pipelineWithQueue:queue];
}

- (void)addRetriable:(UARetriable *)retriable {
    [self.queue addOperation:[UARetriableOperation operationWithRetriable:retriable]];
}

- (void)addChainedRetriables:(NSArray<UARetriable *> *)retriables {

    UARetriableOperation *previousOperation = nil;

    for (UARetriable *retriable in retriables) {
        UARetriableOperation *operation = [UARetriableOperation operationWithRetriable:retriable];

        if (previousOperation) {
            [operation addDependency:previousOperation];

            UA_WEAKIFY(operation)
            previousOperation.cancelBlock = ^{
                UA_STRONGIFY(operation)
                [operation cancel];
            };
        }

        [self.queue addOperation:operation];
        previousOperation = operation;
    }
}

- (void)cancel {
    [self.queue cancelAllOperations];
}

- (void)dealloc {
    [self cancel];
}

@end
