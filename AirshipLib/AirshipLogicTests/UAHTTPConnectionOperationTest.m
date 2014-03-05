
#import "UAHTTPConnectionOperationTest.h"
#import "UAHTTPConnectionOperation.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnection+Test.h" 
#import "UADelayOperation.h"
#import "UATestSynchronizer.h"
#import "NSObject+AnonymousKVO.h"

@interface UAHTTPConnectionOperationTest()
@property(nonatomic, strong) UAHTTPConnectionOperation *operation;
@property(nonatomic, strong) UATestSynchronizer *sync;
@end

@implementation UAHTTPConnectionOperationTest

/* setup and teardown */

- (void)setUp {
    [super setUp];

    self.sync = [[UATestSynchronizer alloc] init];

    [UAHTTPConnection swizzle];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:@"http://jkhadfskhjladfsjklhdfas.com"];

    self.operation = [UAHTTPConnectionOperation operationWithRequest:request onSuccess:^(UAHTTPRequest *request) {
        XCTAssertNil(request.error, @"there should be no error on success");
        // signal completion
        [self.sync continue];
    } onFailure: ^(UAHTTPRequest *request) {
        XCTAssertNotNil(request.error, @"there should be an error on failure");
        // signal completion
        [self.sync continue];
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
    XCTAssertEqual(self.operation.isConcurrent, YES, @"UAHTTPConnectionOperations are concurrent (asynchronous)");
    XCTAssertEqual(self.operation.isExecuting, NO, @"isExecuting will not be set until the operation begins");
    XCTAssertEqual(self.operation.isCancelled, NO, @"isCancelled defaults to NO");
    XCTAssertEqual(self.operation.isFinished, NO, @"isFinished defaults to NO");
}

- (void)testSuccessCase {
    [UAHTTPConnection succeed];
    [self.operation start];
    XCTAssertTrue([self.sync wait], @"timeout should not be reached");
}

- (void)testFailureCase {
    [UAHTTPConnection fail];
    [self.operation start];
    XCTAssertTrue([self.sync wait], @"timeout should not be reached");
}

- (void)testStart {
    [self.operation start];
    XCTAssertTrue([self.sync wait], @"timeout should not be reached");

    XCTAssertEqual(self.operation.isExecuting, NO, @"the operation should no longer be executing");
    XCTAssertEqual(self.operation.isFinished, YES, @"the operation should be finished");
}

- (void)testPreemptiveCancel {
    [self.operation cancel];
    XCTAssertEqual(self.operation.isCancelled, YES, @"you can cancel operations before they have started");
    [self.operation start];

    XCTAssertEqual(self.operation.isExecuting, NO, @"start should have no effect after cancellation");
    XCTAssertEqual(self.operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

- (void)testQueueCancel {
    //create a serial queue
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;

    //add a long running delay in front of our http connection operation
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:25];
    [queue addOperation:delayOperation];
    [queue addOperation:self.operation];

    UADisposable *subscription = [queue observeAtKeyPath:@"operationCount" withBlock:^(id value){
        //stop spinning once the operationCount has reached zero
        if ([value isEqual:@0]) {
            [self.sync continue];
        }
    }];

    //this should eventually drop the operation count, although the change will not be instantaneous
    [queue cancelAllOperations];

    [self.sync wait];

    //we should have an operation count of zero
    XCTAssertTrue(queue.operationCount == 0, @"queue operation count should be zero");

    [subscription dispose];
}

- (void)testInFlightCancel {

    [self.operation start];
    [self.operation cancel];

    [self.sync wait];

    XCTAssertEqual(self.operation.isCancelled, YES, @"the operation should now be canceled");
    XCTAssertEqual(self.operation.isExecuting, NO, @"start should have no effect after cancellation");
    XCTAssertEqual(self.operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

@end
