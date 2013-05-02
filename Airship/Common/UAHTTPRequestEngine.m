
#import "UAHTTPRequestEngine.h"
#import "UAHTTPConnectionOperation.h"
#import "UAGlobal.h"

#define kUARequestEngineDefaultMaxConcurrentRequests 1
#define kUARequestEngineDefaultInitialDelayIntervalSeconds 30
#define kUARequestEngineDefaultMaxDelayIntervalSeconds 300
#define kUARequestEngineDefaultBackoffFactor 2

@interface UAHTTPRequestEngine()
@property(nonatomic, retain) NSOperationQueue *queue;
@end

@implementation UAHTTPRequestEngine

- (id)init {
    if (self = [super init]) {
        self.queue = [[[NSOperationQueue alloc] init] autorelease];
        self.maxConcurrentRequests = kUARequestEngineDefaultMaxConcurrentRequests;
        self.initialDelayIntervalInSeconds = kUARequestEngineDefaultInitialDelayIntervalSeconds;
        self.maxDelayIntervalInSeconds = kUARequestEngineDefaultMaxDelayIntervalSeconds;
        self.backoffFactor = kUARequestEngineDefaultBackoffFactor;
    }
    return self;
}

//Multiply the current delay interval by the backoff factor, clipped at the max value
- (NSInteger)nextBackoff:(NSInteger)currentDelay {
    return MIN(currentDelay*self.backoffFactor, self.maxDelayIntervalInSeconds);
}

//Enqueues two operations, first an operation that sleeps for the specified number of seconds, and next
//a continuation operation with the former as a dependency. Useful for scheduling retries.
- (void)sleepForSeconds:(NSInteger)seconds withContinuation:(UAHTTPConnectionOperation *)continuation {
    NSBlockOperation *sleepOperation = [NSBlockOperation blockOperationWithBlock:^() {
        sleep(seconds);
    }];

    [continuation addDependency:sleepOperation];

    [self.queue addOperation:sleepOperation];
    [self.queue addOperation:continuation];
}

//The core operation used for making connections and retries
- (UAHTTPConnectionOperation *)operationWithRequest:(UAHTTPRequest *)theRequest
                                       succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
                                         retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
                                          onSuccess:(UAHTTPRequestEngineSuccessBlock)successBlock
                                          onFailure:(UAHTTPRequestEngineFailureBlock)failureBlock
                                          withDelay:(NSInteger)delay {

    //Called in a retry condition.
    void (^retry)(UAHTTPRequest *request) = ^(UAHTTPRequest *request) {
        UALOG(@"Retrying connection to %@ in %d seconds", request.url.description, delay);
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
        if (retryWhereBlock(request) || request.error) {
            retry(request);
        } else {
            failureBlock(request);
        }
    };

    UAHTTPConnectionSuccessBlock onConnectionSuccess = ^(UAHTTPRequest *request) {
        //Does this connection success meet our specified requirements?
        if (succeedWhereBlock(request)) {
            //if so, we're done
            successBlock(request);
        } else {
            //otherwise, retry if applicable
            retryIfNecessary(request);
        }
    };

    UAHTTPConnectionFailureBlock onConnectionFailure = ^(UAHTTPRequest *request) {
        retryIfNecessary(request);
    };

    UAHTTPConnectionOperation *operation = [[[UAHTTPConnectionOperation alloc] initWithRequest:theRequest
                                                                                    onSuccess:onConnectionSuccess
                                                                                    onFailure:onConnectionFailure] autorelease];

    return operation;
}

- (void)enqueueRequest:(UAHTTPRequest *)theRequest
          succeedWhere:(UAHTTPRequestEngineWhereBlock)succeedWhereBlock
            retryWhere:(UAHTTPRequestEngineWhereBlock)retryWhereBlock
             onSuccess:(UAHTTPRequestEngineSuccessBlock)successBlock
             onFailure:(UAHTTPRequestEngineFailureBlock)failureBlock
             withDelay:(NSInteger)delay{
    
    UAHTTPConnectionOperation *operation = [self operationWithRequest:theRequest
                                                         succeedWhere:succeedWhereBlock
                                                           retryWhere:retryWhereBlock
                                                            onSuccess:successBlock
                                                            onFailure:failureBlock withDelay:delay];
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

//Cancels all operations currently in the queue, moving them to the finished state.
//This will result in each operation terminating its work as quickly as possible.
//If the queue is serial, this will cause subsequent additions to be run immediately.
- (void)cancelPendingRequests {
    [self.queue cancelAllOperations];
}

- (void)dealloc {
    [self.queue cancelAllOperations];
    self.queue = nil;
    [super dealloc];
}

@end
