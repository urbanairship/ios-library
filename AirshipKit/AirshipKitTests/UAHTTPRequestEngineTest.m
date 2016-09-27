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

#import "UAHTTPRequestEngineTest.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "UAHTTPConnection+Test.h"
#import "UAHTTPConnectionOperation+Internal.h"
#import "UADelayOperation+Internal.h"
#import <OCMock/OCMock.h>

@interface UAHTTPRequestEngineTest()
@property (nonatomic, strong) UAHTTPRequestEngine *engine;
@property (nonatomic, strong) UAHTTPRequest *request;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) id mockQueue;
@end

@implementation UAHTTPRequestEngineTest

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
    [self.mockQueue stopMocking];
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
        XCTFail(@"got an unexpected request type: %@", operation);
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

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    [self.engine
     runRequest:self.request
     succeedWhere:^(UAHTTPRequest *request) {
         return YES;
     }retryWhere:^(UAHTTPRequest *request) {
         return NO;
     }onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(lastDelay, self.engine.initialDelayIntervalInSeconds, @"after one successful try, the last delay should be the initial value");
         [testExpectation fulfill];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay ) {
         XCTFail(@"this should not happen");
         [testExpectation fulfill];
     }];


    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];
}

- (void)testMaxDelayInterval {
    __block NSInteger tries = 1;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

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
         [testExpectation fulfill];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(lastDelay, self.engine.maxDelayIntervalInSeconds, @"at this point, we should have clipped at the max delay interval");
         [testExpectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];}

- (void)testBackoffFactor {
    __block NSInteger tries = 1;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    [self.engine
     runRequest:self.request
     succeedWhere:^(UAHTTPRequest *request) {
         return NO;
     }retryWhere:^(UAHTTPRequest *request) {
         BOOL result = (tries < 2);
         tries++;
         return result;
     }onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTFail(@"this should not happen");
         [testExpectation fulfill];
     }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         XCTAssertEqual(self.engine.initialDelayIntervalInSeconds, lastDelay/self.engine.backoffFactor, @"with two tries, the last delay should be the initial interval * backoff factor");
         [testExpectation fulfill];
     }];

    //give this one a little more time to finish
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run request with error %@.", error);
        }
    }];
}

@end
