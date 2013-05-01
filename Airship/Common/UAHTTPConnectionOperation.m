
#import "UAHTTPConnectionOperation.h"
#import "UAGlobal.h"
#import "UAHTTPConnection.h"

@interface UAHTTPConnectionOperation()

@property(nonatomic, assign) BOOL isConcurrent;
@property(nonatomic, assign) BOOL isExecuting;
@property(nonatomic, assign) BOOL isFinished;
@property(nonatomic, retain) UAHTTPRequest *request;
@property(nonatomic, copy) UAHTTPConnectionSuccessBlock successBlock;
@property(nonatomic, copy) UAHTTPConnectionFailureBlock failureBlock;
@property(nonatomic, retain) UAHTTPConnection *connection;

@end

@implementation UAHTTPConnectionOperation

- (id)initWithRequest:(UAHTTPRequest *)request
               onSuccess:(UAHTTPConnectionSuccessBlock)successBlock
               onFailure:(UAHTTPConnectionFailureBlock)failureBlock {
    if (self = [super init]) {
        self.request = request;
        self.successBlock = successBlock;
        self.failureBlock = failureBlock;
        //setting this property to YES allows us to wrap an otherwise async task and control
        //the executing/finished/cancelled semantics granularly.
        self.isConcurrent = YES;
        self.isExecuting = NO;
        self.isFinished = NO;
        
    }
    return self;
}

- (void)cancelConnectionOnMainThread {    
    [self.connection cancel];
    [self finish];
}

- (void)cancel {
    //the super call affects the isCancelled KVC value, synchronize to avoid a race
    @synchronized(self) {
        [super cancel];
    }

    //since NSURLConnection is asynchronous and designed be used from the main thread, perform connection cancellation there
    [self performSelectorOnMainThread:@selector(cancelConnectionOnMainThread) withObject:nil waitUntilDone:NO];
}

- (void)startConnectionOnMainThread {

    UAHTTPConnectionSuccessBlock onConnectionSuccess = ^(UAHTTPRequest *request) {
        self.successBlock(request);
        [self finish];
    };

    UAHTTPConnectionFailureBlock onConnectionFailure = ^(UAHTTPRequest *request) {
        self.failureBlock(request);
        [self finish];
    };

    self.connection = [UAHTTPConnection connectionWithRequest:self.request successBlock:onConnectionSuccess failureBlock:onConnectionFailure];
    [self.connection start];
}

- (void)start {
    //synchronize change to the isExcecuting KVC value
    @synchronized(self) {
        //we may have already been cancelled at this point, in which case do nothing
        if (self.isCancelled) {
            return;
        }
        self.isExecuting = YES;
    }
    //since NSURLConnection is asynchronous and designed be used from the main thread, perform connection setup/start there
    [self performSelectorOnMainThread:@selector(startConnectionOnMainThread) withObject:nil waitUntilDone:NO];
}

- (void)finish {
    self.connection = nil;
    self.isExecuting = NO;
    self.isFinished = YES;
}

- (void)dealloc {
    [self.connection cancel];
    self.connection = nil;
    self.request = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
    [super dealloc];
}

@end
