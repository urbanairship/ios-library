/* Copyright 2018 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UARetriablePipeline+Internal.h"
#import "UATestDispatcher.h"

@interface UARetriablePipelineTest : UABaseTest
@property (nonatomic, strong) UARetriablePipeline *pipeline;
@property (nonatomic, strong) UATestDispatcher *testDispatcher;
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UARetriablePipelineTest

- (void)setUp {
    [super setUp];

    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 1;

    self.testDispatcher = [UATestDispatcher testDispatcher];
    self.pipeline = [UARetriablePipeline pipelineWithQueue:self.queue dispatcher:self.testDispatcher];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testChain {
    __block NSMutableArray *order = [NSMutableArray array];

    XCTestExpectation *firstExecuted = [self expectationWithDescription:@"first executed"];
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        [order addObject:@"first"];
        completionHandler(UARetriableResultSuccess);
        [firstExecuted fulfill];
    }];

    XCTestExpectation *secondExecuted = [self expectationWithDescription:@"second executed"];
    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        [order addObject:@"second"];
        completionHandler(UARetriableResultSuccess);
        [secondExecuted fulfill];
    }];

    [self.pipeline addChainedRetriables:@[first, second]];

    [self waitForTestExpectations];

    NSArray *expectedOrder = @[@"first", @"second"];
    XCTAssertEqualObjects(expectedOrder, order);
}

- (void)testRetry {
    XCTestExpectation *firstExecuted = [self expectationWithDescription:@"first executed"];
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        completionHandler(UARetriableResultSuccess);
        [firstExecuted fulfill];
    }];

    __block NSUInteger runCount = 0;
    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        completionHandler(UARetriableResultRetry);
        runCount++;
    }];

    [self.pipeline addChainedRetriables:@[first, second]];

    [self waitForTestExpectations];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(1, runCount);

    [self.testDispatcher advanceTime:30];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(2, runCount);

    [self.testDispatcher advanceTime:60];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(3, runCount);
}

- (void)testCancel {
    XCTestExpectation *firstExecuted = [self expectationWithDescription:@"first executed"];
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        completionHandler(UARetriableResultCancel);
        [firstExecuted fulfill];
    }];

    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        XCTFail(@"Should be cancelled");
        completionHandler(UARetriableResultCancel);
    }];

    [self.pipeline addChainedRetriables:@[first, second]];

    [self waitForTestExpectations];

    [self.queue waitUntilAllOperationsAreFinished];
    [self.testDispatcher advanceTime:30];
    [self.queue waitUntilAllOperationsAreFinished];
}

@end
