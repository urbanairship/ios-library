/* Copyright Airship and Contributors */

#import "UADelayOperation+Internal.h"
#import "UABaseTest.h"

@interface UATestDelay : UADelay
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation UATestDelay
-(void)start {
    self.started = YES;
}

- (void)cancel  {
    self.cancelled = YES;
}
@end

@interface UADelayOperationTest : UABaseTest
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UADelayOperationTest

- (void)setUp {
    [super setUp];
    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 1;
}

- (void)testDelay {
    UATestDelay *testDelay = [[UATestDelay alloc] init];
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelay:testDelay];

    [self.queue addOperation:delayOperation];
    [self.queue waitUntilAllOperationsAreFinished];

    // Verify the operation starts the delay
    XCTAssertTrue(testDelay.started);
}

- (void)testCancel {
    UATestDelay *testDelay = [[UATestDelay alloc] init];
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelay:testDelay];

    [delayOperation cancel];
    XCTAssertTrue(testDelay.cancelled);
}

- (void)tearDown {
    self.queue = nil;
    [super tearDown];
}


@end
