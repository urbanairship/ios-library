
#import "UAHTTPConnectionOperation.h"
#import "UAGlobal.h"
#import "UAHTTPConnection.h"

@interface UAHTTPConnectionOperation()

//NSOperation KVO properties

/**
 * Indicates whether the operation is concurrent.
 *
 * Note that in this case, "concurrent" is used in the sense employed by NSOperation and NSOperationQueue,
 * and is not directly related to whether operations executed in a queue are run on a separate thread.
 * Rather, "concurrent" here means something more akin to "asynchronous".
 * See Apple's documentation for more details:
 * 
 * http://developer.apple.com/library/ios/#documentation/cocoa/reference/NSOperation_class/Reference/Reference.html
 */
@property(nonatomic, assign) BOOL isConcurrent;

/**
 * Indicates whether the operation is currently executing.
 */
@property(nonatomic, assign) BOOL isExecuting;

/**
 * Indicates whether the operation has finished.
 */
@property(nonatomic, assign) BOOL isFinished;

//Additional private state

/**
 * The request to be executed.
 */
@property(nonatomic, strong) UAHTTPRequest *request;

/**
 * The UAHTTPConnectionSuccessBlock to be executed if the connection is successful.
 */
@property(nonatomic, copy) UAHTTPConnectionSuccessBlock successBlock;

/**
 * The UAHTTPConnectionFailureBlock to be executed if the connection is unsuccessful.
 */
@property(nonatomic, copy) UAHTTPConnectionFailureBlock failureBlock;

/**
 * The actual HTTP connection, created and run once the operation begins execution.
 */
@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UAHTTPConnectionOperation

- (id)initWithRequest:(UAHTTPRequest *)request
               onSuccess:(UAHTTPConnectionSuccessBlock)successBlock
               onFailure:(UAHTTPConnectionFailureBlock)failureBlock {

    self = [super init];
    if (self) {
        self.request = request;
        self.successBlock = successBlock;
        self.failureBlock = failureBlock;
        //setting isConcurrent to YES allows us to wrap an otherwise async task and control
        //the executing/finished/cancelled semantics granularly.
        self.isConcurrent = YES;
        self.isExecuting = NO;
        self.isFinished = NO;        
    }
    return self;
}

+ (id)operationWithRequest:(UAHTTPRequest *)request
                 onSuccess:(UAHTTPConnectionSuccessBlock)successBlock
                 onFailure:(UAHTTPConnectionFailureBlock)failureBlock {

    return [[UAHTTPConnectionOperation alloc] initWithRequest:request
                                                     onSuccess:successBlock
                                                     onFailure:failureBlock];
}

- (void)setIsExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setIsConcurrent:(BOOL)isConcurrent {
    [self willChangeValueForKey:@"isConcurrent"];
    _isConcurrent = isConcurrent;
    [self didChangeValueForKey:@"isConcurrent"];
}

- (void)setIsFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancelConnectionOnMainThread {
    [self.connection cancel];
}

- (void)cancel {
    //the super call affects the isCancelled KVO value, synchronize to avoid a race
    @synchronized(self) {
        [super cancel];
    }

    //since NSURLConnection is asynchronous and designed be used from the main thread, perform connection cancellation there
    [self performSelectorOnMainThread:@selector(cancelConnectionOnMainThread) withObject:nil waitUntilDone:NO];
}

- (void)startConnectionOnMainThread {

    UAHTTPConnectionSuccessBlock onConnectionSuccess = ^(UAHTTPRequest *request) {
        if (self.successBlock) {
            self.successBlock(request);
        }

        if (!self.isFinished) {
            [self finish];
        }
    };

    UAHTTPConnectionFailureBlock onConnectionFailure = ^(UAHTTPRequest *request) {
        if (self.failureBlock) {
            self.failureBlock(request);
        }
        if (!self.isFinished) {
            [self finish];
        }
    };

    self.connection = [UAHTTPConnection connectionWithRequest:self.request successBlock:onConnectionSuccess failureBlock:onConnectionFailure];
    [self.connection start];
}

- (void)start {
    //synchronize change to the isExecuting KVO value
    @synchronized(self) {
        //we may have already been cancelled at this point, in which case finish and retrun
        if (self.isCancelled) {
            [self finish];
            return;
        }
        self.isExecuting = YES;
    }
    //since NSURLConnection is asynchronous and designed be used from the main thread, perform connection setup/start there
    [self performSelectorOnMainThread:@selector(startConnectionOnMainThread) withObject:nil waitUntilDone:NO];
}

- (void)cleanup {
    self.connection = nil;
    self.failureBlock = nil;
    self.successBlock = nil;
}

- (void)finish {
    [self cleanup];
    self.isExecuting = NO;
    self.isFinished = YES;
}

- (void)dealloc {
    [self.connection cancel];
}

@end
