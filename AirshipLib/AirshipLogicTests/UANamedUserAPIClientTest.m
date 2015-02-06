/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import <XCTest/XCTest.h>
#import <OCMOCK/OCMock.h>
#import "UAConfig.h"
#import "UANamedUserAPIClient.h"
#import "UAirship.h"
#import "UAHTTPRequestEngine.h"
#import "UAHTTPRequest+Internal.h"

@interface UANamedUserAPIClientTest : XCTestCase

@property (nonatomic, strong) id mockRequestEngine;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UANamedUserAPIClient *client;

@end

@implementation UANamedUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturnValue:OCMOCK_VALUE(YES)] ready];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.config] config];

    self.mockRequestEngine = [OCMockObject niceMockForClass:[UAHTTPRequestEngine class]];
    self.client = [UANamedUserAPIClient clientWithRequestEngine:self.mockRequestEngine];
}

- (void)tearDown {
    [self.mockRequestEngine stopMocking];
    [self.mockAirship stopMocking];

    [super tearDown];
}

/**
 * Test associate named user retries on 5xx status codes.
 */
- (void)testAssociateRetriesFailedRequests {

    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:i HTTPVersion:nil headerFields:nil];

            // If shouldRetryOnConnection is NO, never retry
            self.client.shouldRetryOnConnectionError = NO;
            if (retryBlock(request)) {
                return NO;
            }

            // Allow it to retry on 5xx and error results
            self.client.shouldRetryOnConnectionError = YES;
            BOOL retryResult = retryBlock(request);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserId" channelID:@"fakeChannel" onSuccess:nil onFailure:nil];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Associate named user should call retry on 5xx status codes.");
}

/**
 * Test associate named user succeeds request if the status is 200.
 */
-(void)testAssociateSucceedsRequest {
    BOOL (^whereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock whereBlock = obj;
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

        request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:200 HTTPVersion:nil headerFields:nil];
        if (!whereBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:whereBlockCheck]
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserId" channelID:@"fakeChannel" onSuccess:nil onFailure:nil];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Associate named user should succeed on 200 status code.");
}

/**
 * Test associate named user calls the onSuccessBlock when the request is successful.
 */
- (void)testAssociateOnSuccess {
    __block BOOL onSuccessCalled = NO;

    // Set up a request with a valid response body
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    NSString *response = @"{ \"ok\":true }";
    request.responseData = [response dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the run request and call the success block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserId" channelID:@"fakeChannel" onSuccess:^{
        onSuccessCalled = YES;
    } onFailure:nil];

    XCTAssertTrue(onSuccessCalled, @"Associate named user should call onSuccess block when its successful.");
}

/**
 * Test associate named user calls the on FailureBlock with the failed request
 * when the request fails.
 */
- (void)testAssociateOnFailure {
    __block UAHTTPRequest *failedRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

    // Expect the run request and call the failure block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPRequestEngineFailureBlock failureBlock = (__bridge UAHTTPRequestEngineFailureBlock)arg;
        failureBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserId" channelID:@"fakeChannel" onSuccess:nil onFailure:^(UAHTTPRequest *request) {
        failedRequest = request;
    }];

    XCTAssertEqualObjects(request, failedRequest, @"Failure block should return the failed request.");
}

/**
 * Test disassociate named user retries on 5xx status codes.
 */
- (void)testDisassociateRetriesFailedRequests {

    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:i HTTPVersion:nil headerFields:nil];

            // If shouldRetryOnConnection is NO, never retry
            self.client.shouldRetryOnConnectionError = NO;
            if (retryBlock(request)) {
                return NO;
            }

            // Allow it to retry on 5xx and error results
            self.client.shouldRetryOnConnectionError = YES;
            BOOL retryResult = retryBlock(request);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client disassociate:@"fakeChannel" onSuccess:nil onFailure:nil];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Disassociate named user should call retry on 5xx status codes.");
}

/**
 * Test disassociate named user succeeds request if the status is 200.
 */
-(void)testDisassociateSucceedsRequest {
    BOOL (^whereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock whereBlock = obj;
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

        request.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:200 HTTPVersion:nil headerFields:nil];
        if (!whereBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:whereBlockCheck]
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client disassociate:@"fakeChannel" onSuccess:nil onFailure:nil];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Disassociate named user should succeed on 200 status code.");
}

/**
 * Test disassociate named user calls the onSuccessBlock when the request is successful.
 */
- (void)testDisassociateOnSuccess {
    __block BOOL onSuccessCalled = NO;

    // Set up a request with a valid response body
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    NSString *response = @"{ \"ok\":true }";
    request.responseData = [response dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the run request and call the success block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client disassociate:@"fakeChannel" onSuccess:^{
        onSuccessCalled = YES;
    } onFailure:nil];

    XCTAssertTrue(onSuccessCalled, @"Disassociate named user should call onSuccess block when its successful.");
}

/**
 * Test disassociate named user calls the on FailureBlock with the failed request
 * when the request fails.
 */
- (void)testDisassociateOnFailure {
    __block UAHTTPRequest *failedRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

    // Expect the run request and call the failure block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPRequestEngineFailureBlock failureBlock = (__bridge UAHTTPRequestEngineFailureBlock)arg;
        failureBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client disassociate:@"fakeChannel" onSuccess:nil onFailure:^(UAHTTPRequest *request) {
        failedRequest = request;
    }];

    XCTAssertEqualObjects(request, failedRequest, @"Failure block should return the failed request.");
}

@end
