/* Copyright 2018 Urban Airship and Contributors */

#import "UADelayOperation+Internal.h"
#import "UABaseTest.h"

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
    __block BOOL finished = NO;
    [self.queue addOperation:[UADelayOperation operationWithDelayInSeconds:1]];
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        @synchronized(self) {
            finished = YES;
        }
    }]];

    @synchronized(self) {
        XCTAssertFalse(finished, @"flag should not be set until after delay completes");
    }
    //give it enough time to complete
    sleep(2);
    @synchronized(self) {
        XCTAssertTrue(finished, @"flag should be set once delay completes");
    }
}

- (void)testCancel {
    __block BOOL finished = NO;
    //add a long running delay
    [self.queue addOperation:[UADelayOperation operationWithDelayInSeconds:20]];
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        finished = YES;
    }]];

    //give it some time to spin things up
    sleep(1);

    XCTAssertTrue(self.queue.operationCount == 2, @"we should have two operations running");
    [self.queue cancelAllOperations];

    //give it some time to wind things down
    sleep(1);

    XCTAssertFalse(finished, @"flag should still be unset");
    XCTAssertTrue(self.queue.operationCount == 0, @"operation count should be zero");
}

- (void)tearDown {
    self.queue = nil;
    [super tearDown];
}


@end
