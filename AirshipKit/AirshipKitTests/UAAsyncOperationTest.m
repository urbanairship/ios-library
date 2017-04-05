/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAAsyncOperation+Internal.h"

@interface UAAsyncOperationTest : XCTestCase
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UAAsyncOperationTest

- (void)setUp {
    [super setUp];
    self.queue = [[NSOperationQueue alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test async block is called for the operation.
 */
- (void)testPerform {
    XCTestExpectation *blockCalled = [self expectationWithDescription:@"Block called"];

    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        XCTAssertTrue(operation.isExecuting);
        XCTAssertFalse(operation.isFinished);

        [operation finish];

        XCTAssertTrue(operation.isFinished);
        XCTAssertFalse(operation.isExecuting);

        [blockCalled fulfill];
    }];

    [self.queue addOperation:operation];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
