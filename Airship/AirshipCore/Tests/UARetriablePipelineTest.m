/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARetriablePipeline+Internal.h"
#import "AirshipTests-Swift.h"

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

    self.testDispatcher = [[UATestDispatcher alloc] init];
    self.pipeline = [UARetriablePipeline pipelineWithQueue:self.queue dispatcher:self.testDispatcher];
}

- (void)testChain {
    __block NSMutableArray *order = [NSMutableArray array];

    XCTestExpectation *firstExecuted = [self expectationWithDescription:@"first executed"];
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        [order addObject:@"first"];
        completionHandler(UARetriableResultSuccess, 0);
        [firstExecuted fulfill];
    }];

    XCTestExpectation *secondExecuted = [self expectationWithDescription:@"second executed"];
    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        [order addObject:@"second"];
        completionHandler(UARetriableResultSuccess, 0);
        [secondExecuted fulfill];
    }];

    [self.pipeline addChainedRetriables:@[first, second]];

    [self waitForTestExpectations];

    NSArray *expectedOrder = @[@"first", @"second"];
    XCTAssertEqualObjects(expectedOrder, order);
}

- (void)testRetry {
    __block NSUInteger firstRunCount = 0;
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        firstRunCount++;
        completionHandler(UARetriableResultSuccess, 0);
    }];

    __block NSUInteger secondRunCount = 0;
    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        secondRunCount++;
        completionHandler(UARetriableResultRetry, 0);
    }];

    [self.pipeline addChainedRetriables:@[first, second]];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(1, firstRunCount);
    XCTAssertEqual(1, secondRunCount);

    [self.testDispatcher advanceTime:30];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(1, firstRunCount);
    XCTAssertEqual(2, secondRunCount);

    [self.testDispatcher advanceTime:60];
    [self.queue waitUntilAllOperationsAreFinished];

    XCTAssertEqual(1, firstRunCount);
    XCTAssertEqual(3, secondRunCount);
}

- (void)testCancel {
    XCTestExpectation *firstExecuted = [self expectationWithDescription:@"first executed"];
    UARetriable *first = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        completionHandler(UARetriableResultCancel, 0);
        [firstExecuted fulfill];
    }];

    UARetriable *second = [UARetriable retriableWithRunBlock:^(UARetriableCompletionHandler completionHandler) {
        XCTFail(@"Should be cancelled");
        completionHandler(UARetriableResultCancel, 0);
    }];

    [self.pipeline addChainedRetriables:@[first, second]];

    [self waitForTestExpectations];

    [self.queue waitUntilAllOperationsAreFinished];
    [self.testDispatcher advanceTime:30];
    [self.queue waitUntilAllOperationsAreFinished];
}

@end
