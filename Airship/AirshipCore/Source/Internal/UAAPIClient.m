/* Copyright Airship and Contributors */

#import "UAAPIClient.h"
#import "UARequestSession.h"
#import "UARuntimeConfig.h"
#import "UAirship.h"
#import "UAHTTPRequestOperation+Internal.h"
#import "UADelayOperation+Internal.h"

NSUInteger const UAAPIClientStatusUnavailable = 0;

static NSTimeInterval const InitialDelay = 30;
static NSTimeInterval const MaxBackOff = 3000;

@interface UAAPIClient()
@property(nonatomic, strong) UARuntimeConfig *config;
@property(nonatomic, strong) UARequestSession *session;
@property(nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UAAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session {
    return [self initWithConfig:config session:session queue:nil];
}

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
                         queue:(NSOperationQueue *)queue {
    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
        self.enabled = YES;

        if (!queue) {
            queue = [[NSOperationQueue alloc] init];
            queue.maxConcurrentOperationCount = 1;
        }

        self.queue = queue;
    }

    return self;
}

- (void)cancelAllRequests {
    [self.queue cancelAllOperations];
}

- (void)dealloc {
    [self cancelAllRequests];
}

- (void)performRequest:(UARequest *)request
     completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {
    [self performRequest:request retryWhere:nil completionHandler:completionHandler];
}

- (void)performRequest:(UARequest *)request
            retryWhere:(nullable UAHTTPRequestRetryBlock)retryBlock
     completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {

    NSOperation *operation = [self operationWithRequest:request
                                             retryDelay:InitialDelay
                                             retryWhere:retryBlock
                                      completionHandler:completionHandler];

    [self.queue addOperation:operation];
}

- (NSOperation *)operationWithRequest:(UARequest *)request
                           retryDelay:(NSTimeInterval)retryDelay
                           retryWhere:(UAHTTPRequestRetryBlock)retryBlock
                    completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {

    UAHTTPRequestOperation *operation = [UAHTTPRequestOperation operationWithRequest:request
                                                                             session:self.session
                                                                   completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

        if (!error && retryBlock && retryBlock(data, response)) {
            UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:retryDelay];
            NSOperation *retryOperation = [self operationWithRequest:request
                                                          retryDelay:MIN(retryDelay * 2, MaxBackOff)
                                                          retryWhere:retryBlock
                                                   completionHandler:completionHandler];

            [retryOperation addDependency:delayOperation];

            [self.queue addOperation:delayOperation];
            [self.queue addOperation:retryOperation];

            return;
        } else {
            completionHandler(data, response, error);
        }
    }];

    return operation;
}

@end

