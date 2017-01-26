/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <XCTest/XCTest.h>
#import <OCMOCK/OCMock.h>
#import "UAConfig.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAirship.h"

@interface UANamedUserAPIClientTest : XCTestCase

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UANamedUserAPIClient *client;

@end

@implementation UANamedUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.config] config];

    self.client = [UANamedUserAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockAirship stopMocking];

    [super tearDown];
}

/**
 * Test associate named user retries on 5xx status codes.
 */
- (void)testAssociateRetriesFailedRequests {
    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];

            BOOL retryResult = retryBlock(nil, response);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:400
                                                                 HTTPVersion:nil
                                                                headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    [self.mockSession verify];
}

/**
 * Test associate named user succeeds request when status is 2xx.
 */
-(void)testAssociateSucceedsRequest {
    __block int successBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     successBlockCalls++;
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);

    [self.mockSession verify];
}

/**
 * Test associate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testAssociateOnFailure {
    __block int failureBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 500; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client associate:@"fakeNamedUserID"
                 channelID:@"fakeChannel"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     failureBlockCalls++;
                 }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 100);
    
    [self.mockSession verify];
}

/**
 * Test disassociate named user retries on 5xx status codes.
 */
- (void)testDisassociateRetriesFailedRequests {

    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            BOOL retryResult = retryBlock(nil, response);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                  statusCode:400
                                                                 HTTPVersion:nil
                                                                headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client disassociate:@"fakeNamedUserID" onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger status) {
        XCTFail(@"Should not be called");

    }];

    [self.mockSession verify];
}

/**
 * Test disassociate named user succeeds request when status is 2xx.
 */
-(void)testDisassociateSucceedsRequest {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int successBlockCalls = 0;

    [self.client disassociate:@"fakeNamedUserID"
                 onSuccess:^{
                     successBlockCalls++;
                 }
                 onFailure:^(NSUInteger status){
                     XCTFail(@"Should not be called");
                 }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);
    
    [self.mockSession verify];
}

/**
 * Test disassociate named user calls the FailureBlock with the failed request
 * when the request fails.
 */
- (void)testDisassociateOnFailure {
    __block int failureBlockCalls = 0;

    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 500; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                                      statusCode:i
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    [self.client disassociate:@"fakeNamedUserID"
                 onSuccess:^{
                     XCTFail(@"Should not be called");
                 }
                 onFailure:^(NSUInteger status){
                     failureBlockCalls++;
                 }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 100);
    
    [self.mockSession verify];
}

@end
