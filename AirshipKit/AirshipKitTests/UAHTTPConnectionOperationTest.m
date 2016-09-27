/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAHTTPConnectionOperationTest.h"
#import "UAHTTPConnectionOperation+Internal.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnection+Test.h" 
#import "UADelayOperation+Internal.h"
#import "NSObject+AnonymousKVO.h"

@interface UAHTTPConnectionOperationTest()
@property (nonatomic, strong) UAHTTPRequest *request;
@end

@implementation UAHTTPConnectionOperationTest

/* setup and teardown */

- (void)setUp {
    [super setUp];

    self.request = [UAHTTPRequest requestWithURLString:@"http://jkhadfskhjladfsjklhdfas.com"];

    [UAHTTPConnection swizzle];
}

- (void)tearDown {
    // Tear-down code here.
    [UAHTTPConnection unSwizzle];
    self.request = nil;
    [super tearDown];
}

/* tests */

- (void)testDefaults {

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request
                                                                                 onSuccess:^(UAHTTPRequest *request){}
                                                                                 onFailure:^(UAHTTPRequest *request){}];

    XCTAssertEqual(operation.isConcurrent, YES, @"UAHTTPConnectionOperations are concurrent (asynchronous)");
    XCTAssertEqual(operation.isExecuting, NO, @"isExecuting will not be set until the operation begins");
    XCTAssertEqual(operation.isCancelled, NO, @"isCancelled defaults to NO");
    XCTAssertEqual(operation.isFinished, NO, @"isFinished defaults to NO");
}

- (void)testSuccessCase {
    [UAHTTPConnection succeed];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"operation finished"];

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request onSuccess:^(UAHTTPRequest *request) {
        XCTAssertNil(request.error, @"there should be no error on success");
        [testExpectation fulfill];
    } onFailure:^(UAHTTPRequest *request){}];

    [operation start];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run operation with error %@.", error);
        }
    }];
}

- (void)testFailureCase {
    [UAHTTPConnection fail];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"operation finished"];

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request
                                                                                 onSuccess:^(UAHTTPRequest *request){}
                                                                                 onFailure:^(UAHTTPRequest *request) {

                                                                                     XCTAssertNotNil(request.error, @"there should be an error on failure");
                                                                                     [testExpectation fulfill];
                                                                                 }];

    [operation start];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run operation with error %@.", error);
        }
    }];
}

- (void)testStart {
    [UAHTTPConnection succeed];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"operation finished"];

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request onSuccess:^(UAHTTPRequest *request) {
        XCTAssertNil(request.error, @"there should be no error on success");

        [testExpectation fulfill];
    } onFailure:^(UAHTTPRequest *request){}];

    [operation start];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run operation with error %@.", error);
        }
    }];

    XCTAssertEqual(operation.isExecuting, NO, @"the operation should no longer be executing");
    XCTAssertEqual(operation.isFinished, YES, @"the operation should be finished");
}

- (void)testPreemptiveCancel {

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request
                                                                                 onSuccess:^(UAHTTPRequest *request){}
                                                                                 onFailure:^(UAHTTPRequest *request){}];

    [operation cancel];
    XCTAssertEqual(operation.isCancelled, YES, @"you can cancel operations before they have started");

    [operation start];
    XCTAssertEqual(operation.isExecuting, NO, @"start should have no effect after cancellation");
    XCTAssertEqual(operation.isFinished, YES, @"cancelled operations always move to the finished state");
}


- (void)testQueueCancel {

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"operation finished"];

    //create a serial queue
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;

    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request
                                                                                 onSuccess:^(UAHTTPRequest *request){}
                                                                                 onFailure:^(UAHTTPRequest *request){}];

    //add a long running delay in front of our http connection operation
    UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:25];
    [queue addOperation:delayOperation];
    [queue addOperation:operation];

    UADisposable *subscription = [queue observeAtKeyPath:@"operationCount" withBlock:^(id value){
        //stop spinning once the operationCount has reached zero
        if ([value isEqual:@0]) {
            [testExpectation fulfill];
        }
    }];

    //this should eventually drop the operation count, although the change will not be instantaneous
    [queue cancelAllOperations];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run operation with error %@.", error);
        }
    }];

    //we should have an operation count of zero
    XCTAssertTrue(queue.operationCount == 0, @"queue operation count should be zero");

    [subscription dispose];
}

- (void)testInFlightCancel {
    UAHTTPConnectionOperation *operation = [UAHTTPConnectionOperation operationWithRequest:self.request
                                                                                 onSuccess:^(UAHTTPRequest *request){}
                                                                                 onFailure:^(UAHTTPRequest *request){}];

    [operation start];
    [operation cancel];

    XCTAssertEqual(operation.isCancelled, YES, @"operation should have moved to the cancelled state");
    XCTAssertEqual(operation.isExecuting, NO, @"start should have no effect after cancellation");
    XCTAssertEqual(operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

@end
