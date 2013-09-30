
#import "UAHTTPRequestEngineTest.h"
#import "UAHTTPRequestEngine.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnectionOperation.h"
#import "UADelayOperation.h"
#import <OCMock/OCMock.h>

@interface UAHTTPRequestEngineTest()
@property(nonatomic, strong) UAHTTPRequestEngine *engine;
@property(nonatomic, strong) UAHTTPRequest *request;
@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) id mockQueue;
#if OS_OBJECT_USE_OBJC
@property(nonatomic, strong) dispatch_semaphore_t semaphore;    // GCD objects use ARC
#else
@property(nonatomic, assign) dispatch_semaphore_t semaphore;    // GCD object don't use ARC
#endif
@end

@implementation UAHTTPRequestEngineTest

/* convenience methods for async/runloop manipulation */

//spin the current run loop until we get a completion signal
- (void)waitUntilDone {
    self.semaphore = dispatch_semaphore_create(0);

    while (dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_NOW))
        //this is effectively a 10 second timeout, in case something goes awry
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    #if !OS_OBJECT_USE_OBJC
    dispatch_release(self.semaphore);
    #endif
}

//send a completion signal
- (void)done {
    dispatch_semaphore_signal(self.semaphore);
}

//wait until the next iteration of the run loop
- (void)waitUntilNextRunLoopIteration {
    [self performSelector:@selector(done) withObject:nil afterDelay:0];
    [self waitUntilDone];
}


/* setup and teardown */

- (void)setUp {
    [super setUp];

    [UAHTTPConnection swizzle];

    self.queue = [[NSOperationQueue alloc] init];
    self.mockQueue = [OCMockObject partialMockForObject:self.queue];
    [[[self.mockQueue stub] andCall:@selector(fakeAddOperation:) onObject:self] addOperation:[OCMArg any]];

    self.engine = [[UAHTTPRequestEngine alloc] initWithQueue:self.mockQueue];
    self.request = [UAHTTPRequest requestWithURLString:@"http://jkhadfskhjladfsjklhdfas.com"];

}

- (void)tearDown {
    // Tear-down code here.
    [UAHTTPConnection unSwizzle];
    self.engine = nil;
    self.request = nil;
    self.queue = nil;
    self.mockQueue = nil;
    [super tearDown];
}

- (void)fakeAddOperation:(id)operation {
    if ([operation isKindOfClass:[UAHTTPConnectionOperation class]]) {
        [(UAHTTPConnection *)operation start];
    } else if ([operation isKindOfClass:[NSBlockOperation class]]) {
        NSInteger seconds = ((UADelayOperation *)operation).seconds;
        NSLog(@"quote unquote sleeping for %ld seconds", (long)seconds);
    } else {
        XCTFail(@"got an unexpected operation type: %@", operation);
    }
}

/* tests */

- (void)testDefaults {
    XCTAssertEqual(self.engine.maxConcurrentRequests, (NSUInteger)kUARequestEngineDefaultMaxConcurrentRequests, @"default value should be set to preprocessor constant");
    XCTAssertEqual(self.engine.initialDelayIntervalInSeconds, (NSUInteger)kUARequestEngineDefaultInitialDelayIntervalSeconds, @"default value should be set to preprocessor constant");
    XCTAssertEqual(self.engine.maxDelayIntervalInSeconds, (NSUInteger)kUARequestEngineDefaultMaxDelayIntervalSeconds, @"default value should be set to preprocessor constant");
    XCTAssertEqual(self.engine.backoffFactor, (NSUInteger)kUARequestEngineDefaultBackoffFactor, @"default value should be set to preprocessor constant");
}

- (void)testMaxConcurrentRequests {
    XCTAssertEqual(self.engine.maxConcurrentRequests, (NSUInteger)self.engine.queue.maxConcurrentOperationCount, @"max concurrent requests is constrained by the concurrent operation count of the queue");
}

- (void)testInitialDelayInterval {
    [self.engine
     runRequest:self.request
     succeedWhere:^(UAHTTPRequest *request) {
         return YES;
     }retryWhere:^(UAHTTPRequest *request) {
         return NO;
     }onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(lastDelay, self.engine.initialDelayIntervalInSeconds, @"after one successful try, the last delay should be the initial value");
         [self done];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay ) {
         XCTFail(@"this should not happen");
         [self done];
     }];

    [self waitUntilDone];
}

- (void)testMaxDelayInterval {
    __block NSInteger tries = 1;
    [self.engine
     runRequest:self.request
     succeedWhere:^(UAHTTPRequest *request) {
         return NO;
     }retryWhere:^(UAHTTPRequest *request) {
         BOOL result = (tries < 10);
         tries++;
         return result;
     }onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTFail(@"this should not happen");
         [self done];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(lastDelay, self.engine.maxDelayIntervalInSeconds, @"at this point, we should have clipped at the max delay interval");
         [self done];
     }];

    [self waitUntilDone];    
}

- (void)testBackoffFactor {
    __block NSInteger tries = 1;
    [self.engine
     runRequest:self.request
     succeedWhere:^(UAHTTPRequest *request) {
         return NO;
     }retryWhere:^(UAHTTPRequest *request) {
         BOOL result = (tries < 2);
         tries++;
         return result;
     }onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTFail(@"this hould not happen");
         [self done];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(self.engine.initialDelayIntervalInSeconds, lastDelay/self.engine.backoffFactor, @"with two tries, the last delay should be the initial interval * backoff factor");
         [self done];
     }];

    [self waitUntilDone];
}

@end
