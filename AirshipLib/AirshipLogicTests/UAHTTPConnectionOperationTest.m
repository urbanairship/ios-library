/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import "UAHTTPConnectionOperation.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnection+Test.h" 
#import "UADelayOperation.h"
#import "UATestSynchronizer.h"
#import "NSObject+AnonymousKVO.h"

@interface UAHTTPConnectionOperationTest()
@property (nonatomic, strong) UAHTTPConnectionOperation *operation;
@property (nonatomic, strong) UATestSynchronizer *sync;
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

    [UAHTTPConnection succeed];
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

    XCTAssertEqual(self.operation.isCancelled, YES, @"operation should have moved to the cancelled state");
    XCTAssertEqual(self.operation.isExecuting, NO, @"start should have no effect after cancellation");
    XCTAssertEqual(self.operation.isFinished, YES, @"cancelled operations always move to the finished state");
}

@end
