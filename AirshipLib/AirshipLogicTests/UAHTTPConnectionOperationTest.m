
#import "UAHTTPConnectionOperationTest.h"
#import "UAHTTPConnectionOperation.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnection+Test.h" 
#import "UADelayOperation.h"

@interface UAHTTPConnectionOperationTest()
@property(nonatomic, retain) UAHTTPConnectionOperation *operation;
@property(nonatomic, assign) dispatch_semaphore_t semaphore;
@end

@implementation UAHTTPConnectionOperationTest

/* convenience methods for async/runloop manipulation */

//spin the current run loop until we get a completion signal
- (void)waitUntilDone {
    self.semaphore = dispatch_semaphore_create(0);

    while (dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_NOW))
        //this is effectively a 10 second timeout, in case something goes awry
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    dispatch_release(self.semaphore);
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

    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:@"http://jkhadfskhjladfsjklhdfas.com"];

    self.operation = [UAHTTPConnectionOperation operationWithRequest:request onSuccess:^(UAHTTPRequest *request) {
        STAssertNil(request.error, @"there should be no error on success");
        //signal completion
        [self done];
    } onFailure: ^(UAHTTPRequest *request) {
        STAssertNotNil(request.error, @"there should be an error on failure");
        //signal completion
        [self done];
    }];
}

- (void)tearDown {
    // Tear-down code here.
    [UAHTTPConnection unSwizzle];
    self.operation = nil;
    [super tearDown];
}

/* tests */

- (void)testDefaults {
    STAssertEquals(self.operation.isConcurrent, YES, @"UAHTTPConnectionOperations are concurrent (asynchronous)");
    STAssertEquals(self.operation.isExecuting, NO, @"isExecuting will not be set until the operation begins");
    STAssertEquals(self.operation.isCancelled, NO, @"isCancelled defaults to NO");
    STAssertEquals(self.operation.isFinished, NO, @"isFinished defaults to NO");
}

- (void)testSuccessCase {
    [UAHTTPConnection succeed];
    [self.operation start];
    [self waitUntilDone];
}

- (void)testFailureCase {
    [UAHTTPConnection fail];
    [self.operation start];
    [self waitUntilDone];
}

- (void)testStart {

    [self.operation start];
    [self waitUntilDone];
    
    STAssertEquals(self.operation.isExecuting, NO, @"the operation should no longer be executing");
    STAssertEquals(self.operation.isFinished, YES, @"the operation should be finished");
}

- (void)testPreemptiveCancel {
    [self.operation cancel];
    STAssertEquals(self.operation.isCancelled, YES, @"you can cancel operations before they have started");
    [self.operation start];

    [self waitUntilNextRunLoopIteration];

    STAssertEquals(self.operation.isExecuting, NO, @"start should have no effect after cancellation");
    STAssertEquals(self.operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

- (void)testQueueCancel {
    //create a serial queue
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    queue.maxConcurrentOperationCount = 1;

    //add a long running delay in front of our http connection operation
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:25];
    [queue addOperation:delayOperation];
    [queue addOperation:self.operation];

    //give the queue a little time to spin things up
    sleep(1);

    [queue cancelAllOperations];

    //give the queue a little time to wind things down
    sleep(1);

    //we should have an operation count of zero
    STAssertTrue(queue.operationCount == 0, @"queue operation count should be zero");
}

- (void)testInFlightCancel {
    [self.operation start];
    [self.operation cancel];
    [self waitUntilNextRunLoopIteration];
    STAssertEquals(self.operation.isCancelled, YES, @"the operation should now be canceled");
    [self waitUntilNextRunLoopIteration];
    STAssertEquals(self.operation.isExecuting, NO, @"start should have no effect after cancellation");
    STAssertEquals(self.operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

@end
