
#import "UAHTTPRequestEngine.h"
#import "UADelayOperation.h"
#import "UAHTTPConnectionOperation.h"
#import "UAGlobal.h"

@interface UAHTTPRequestEngine()
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UAHTTPRequestEngine

- (instancetype)initWithQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        self.queue = queue;
        self.queue.maxConcurrentOperationCount = kUARequestEngineDefaultMaxConcurrentRequests;
        self.maxConcurrentRequests = kUARequestEngineDefaultMaxConcurrentRequests;
        self.initialDelayIntervalInSeconds = kUARequestEngineDefaultInitialDelayIntervalSeconds;
        self.maxDelayIntervalInSeconds = kUARequestEngineDefaultMaxDelayIntervalSeconds;
        self.backoffFactor = kUARequestEngineDefaultBackoffFactor;
    }
    return self;
}

- (instancetype)init {
    return [self initWithQueue:[[NSOperationQueue alloc] init]];
}

//Multiply the current delay interval by the backoff factor, clipped at the max value
- (NSUInteger)nextBackoff:(NSUInteger)currentDelay {
    return MIN(currentDelay*self.backoffFactor, self.maxDelayIntervalInSeconds);
}

//Enqueues two operations, first an operation that sleeps for the specified number of seconds, and next
//a continuation operation with the former as a dependency. Useful for scheduling retries.
- (void)sleepForSeconds:(NSUInteger)seconds withContinuation:(UAHTTPConnectionOperation *)continuation {
    UADelayOperation *delay = [UADelayOperation operationWithDelayInSeconds:seconds];
    [continuation addDependency:delay];

    [self.queue addOperation:delay];
    [self.queue addOperation:continuation];
}

//The core operation used for making connections and retries
- (UAHTTPConnectionOperation *)operationWithRequest:(UAHTTPRequest *)theRequest
                                       succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
                                         retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
                                          onSuccess:(UAHTTPRequestEngineSuccessBlock)successBlock
                                          onFailure:(UAHTTPRequestEngineFailureBlock)failureBlock
                                          withDelay:(NSUInteger)delay {

    //Called in a retry condition.
    void (^retry)(UAHTTPRequest *request) = ^(UAHTTPRequest *request) {
        UA_LDEBUG(@"Retrying connection to %@ in %lu seconds", request.url.description, (unsigned long)delay);

        [self sleepForSeconds:delay withContinuation:
            [self operationWithRequest:theRequest
                    succeedWhere:succeedWhereBlock
                      retryWhere:retryWhereBlock
                       onSuccess:successBlock
                       onFailure:failureBlock
                       //increment the delay interval for next time, if needed
                       withDelay:[self nextBackoff:delay]]
        ];
    };

    //Determines whether a retry is desireable and does so accordingly. Otherwise, fail.
    void (^retryIfNecessary)(UAHTTPRequest *request) = ^(UAHTTPRequest *request) {
        BOOL shouldRetry = NO;
        if (retryWhereBlock) {
            if (retryWhereBlock(request)) {
                shouldRetry = YES;
            }
        } else {
            UA_LERR(@"missing retryWhereBlock");
        }

        if (shouldRetry) {
            retry(request);
        } else {
            if (failureBlock) {
                failureBlock(request, delay);
            } else {
                UA_LERR(@"missing successBlock");
            }
        }
    };

    UAHTTPConnectionSuccessBlock onConnectionSuccess = ^(UAHTTPRequest *request) {
        if (succeedWhereBlock) {
            //Does this connection success meet our specified requirements?
            if (succeedWhereBlock(request)) {
                //if so, we're done
                if (successBlock ) {
                    successBlock(request, delay);
                } else {
                    UA_LERR(@"missing successBlock");
                }
            } else {
                //otherwise, retry if applicable
                retryIfNecessary(request);
            }
        } else {
            UA_LERR(@"missing succeedWhereBlock");
        }
    };

    UAHTTPConnectionFailureBlock onConnectionFailure = ^(UAHTTPRequest *request) {
        retryIfNecessary(request);
    };

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:theRequest
                                                                                    onSuccess:onConnectionSuccess
                                                                                    onFailure:onConnectionFailure];

    return operation;
}

- (void)enqueueRequest:(UAHTTPRequest *)theRequest
          succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
            retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
             onSuccess:(UAHTTPRequestEngineSuccessBlock)successBlock
             onFailure:(UAHTTPRequestEngineFailureBlock)failureBlock
             withDelay:(NSUInteger)delay{
    
    UAHTTPConnectionOperation *operation = [self operationWithRequest:theRequest
                                                         succeedWhere:succeedWhereBlock
                                                           retryWhere:retryWhereBlock
                                                            onSuccess:successBlock
                                                            onFailure:failureBlock
                                                            withDelay:delay];
    [self.queue addOperation:operation];
}

//The main interface to the outside world, implicitly passes the initial delay interval
- (void)runRequest:(UAHTTPRequest *)theRequest
      succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
        retryWhere:(UAHTTPRequestEngineWhereBlock)retryBlock
         onSuccess:(UAHTTPRequestEngineSuccessBlock)successBlock
         onFailure:(UAHTTPRequestEngineFailureBlock)failureBlock {

    [self enqueueRequest:theRequest
            succeedWhere:succeedWhereBlock
              retryWhere:retryBlock
               onSuccess:successBlock
               onFailure:failureBlock
               withDelay:self.initialDelayIntervalInSeconds];
}

//Cancels all operations currently executing or waiting in the queue, moving them to the finished state.
//This will result in each operation terminating its work as quickly as possible.
//If the queue is serial, this will cause subsequent additions to be run immediately.
- (void)cancelAllRequests {
    [self.queue cancelAllOperations];
}

- (void)dealloc {
    [self.queue cancelAllOperations];
}

@end
