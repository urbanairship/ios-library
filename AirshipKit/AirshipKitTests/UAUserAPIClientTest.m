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

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAHTTPRequestEngine+Internal.h"
#import "UAUserAPIClient.h"
#import "UAHTTPRequest+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUtils.h"
#import "UAConfig+Internal.h"
#import "UAirship+Internal.h"
#import "UAUserAPIClient.h"
#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"


@interface UAUserAPIClientTest : XCTestCase
@property (nonatomic, strong) UAUserAPIClient *client;
@property (nonatomic, strong) id mockRequestEngine;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockUser;

@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockRequestEngine = [OCMockObject niceMockForClass:[UAHTTPRequestEngine class]];
    self.client = [UAUserAPIClient clientWithConfig:self.config];
    self.client.requestEngine = self.mockRequestEngine;

    self.mockUAUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"deviceID"] deviceID];

    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andReturn:@"userName"] username];
    [[[self.mockUser stub] andReturn:@"userPassword"] password];
}

- (void)tearDown {
    [self.mockRequestEngine stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUser stopMocking];

    [super tearDown];
}

/**
 * Test create user retry
 */
-(void)testCreateUserRetry {

    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(request)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^succeedsWhereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock succeedsBlock = obj;

        // Check that it returns YES for 201
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];
        if (succeedsBlock(request)) {
            return YES;
        }
        
        return NO;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:succeedsWhereBlockCheck]
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){}
                               onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should call retry on 500 status codes and succeed on 201.");
}

/**
 * Test create user success
 */
-(void)testCreateUserSuccess {
    __block UAUserData *successData;
    __block NSDictionary *successPayload;

    // Create a valid response
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    NSDictionary *response = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};
    request.responseData = [NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    };

    [[[self.mockRequestEngine expect] andDo:andDoBlock] runRequest:OCMOCK_ANY
                                                      succeedWhere:OCMOCK_ANY
                                                        retryWhere:OCMOCK_ANY
                                                         onSuccess:OCMOCK_ANY
                                                         onFailure:OCMOCK_ANY];


    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   successData = data;
                                   successPayload = payload;
                               }
                               onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should make a create user request.");
    XCTAssertEqualObjects(@"someUserName", successData.username, @"User name is not being parsed from the response.");
    XCTAssertEqualObjects(@"somePassword", successData.password, @"User password is not being parsed from the response.");
    XCTAssertEqualObjects(@"http://url.com", successData.url, @"User url is not being parsed from the response.");
}

/**
 * Test create user failure
 */
-(void)testCreateUserFailure {

    __block UAHTTPRequest *failureRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPConnectionFailureBlock failureBlock = (__bridge UAHTTPConnectionFailureBlock)arg;
        failureBlock(request);
    };

    [[[self.mockRequestEngine expect] andDo:andDoBlock] runRequest:OCMOCK_ANY
                                                      succeedWhere:OCMOCK_ANY
                                                        retryWhere:OCMOCK_ANY
                                                         onSuccess:OCMOCK_ANY
                                                         onFailure:OCMOCK_ANY];


    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){}
                               onFailure:^(UAHTTPRequest *request){
                                   failureRequest = request;
                               }];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should make a create user request.");
    XCTAssertEqualObjects(failureRequest, request, @"Failure should pass the failed request back");
}

/**
 * Test create user request with a channel ID
 */
-(void)testCreateUserRequestChannelID {
    NSDictionary *expectedRequestBody = @{@"ua_device_id": @"deviceID", @"ios_channels": @[@"channelID"]};

    BOOL (^checkRequestBlock)(id)= ^(id obj){
        UAHTTPRequest *request = obj;
        NSString *requestString = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
        id data = [NSJSONSerialization objectWithString:requestString];
        return [expectedRequestBody isEqualToDictionary:data];
    };

    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                    succeedWhere:OCMOCK_ANY
                                      retryWhere:OCMOCK_ANY
                                       onSuccess:OCMOCK_ANY
                                       onFailure:OCMOCK_ANY];

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){}
                               onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should make a create user request.");
}

/**
 * Test update user retry
 */
-(void)testUpdateUserRetry {

    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(request)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^succeedsWhereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock succeedsBlock = obj;

        // Check that it returns YES for 201
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];
        if (succeedsBlock(request)) {
            return YES;
        }

        return NO;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:succeedsWhereBlockCheck]
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^{}
                  onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update user should call retry on 500 status codes and succeed on 201.");
}

/**
 * Test update user success
 */
-(void)testUpdateUserSuccess {
    __block BOOL successBlockCalled = NO;

    // Create a valid response
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    };

    [[[self.mockRequestEngine expect] andDo:andDoBlock] runRequest:OCMOCK_ANY
                                                      succeedWhere:OCMOCK_ANY
                                                        retryWhere:OCMOCK_ANY
                                                         onSuccess:OCMOCK_ANY
                                                         onFailure:OCMOCK_ANY];


    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^{
                      successBlockCalled = YES;
                  }
                  onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update user should make an update user request.");
    XCTAssertTrue(successBlockCalled, @"Success block should be called on success");
}

/**
 * Test update user failure
 */
-(void)testUpdateUserFailure {

    __block UAHTTPRequest *failureRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPConnectionFailureBlock failureBlock = (__bridge UAHTTPConnectionFailureBlock)arg;
        failureBlock(request);
    };

    [[[self.mockRequestEngine expect] andDo:andDoBlock] runRequest:OCMOCK_ANY
                                                      succeedWhere:OCMOCK_ANY
                                                        retryWhere:OCMOCK_ANY
                                                         onSuccess:OCMOCK_ANY
                                                         onFailure:OCMOCK_ANY];

    [self.client updateUser:self.mockUser
                  channelID:@"channel"
                  onSuccess:^{}
                  onFailure:^(UAHTTPRequest *request) {
                      failureRequest = request;
                  }];
    

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update user should make an update user request.");
    XCTAssertEqualObjects(failureRequest, request, @"Failure should pass the failed request back");
}


/**
 * Test update user request payload adds and removes the right things.
 */
-(void)testUpdateUserRequest {
    __block NSDictionary *expectedRequestBody;

    BOOL (^checkRequestBlock)(id)= ^(id obj){
        UAHTTPRequest *request = obj;

        if (![request.url.absoluteString isEqualToString:@"https://device-api.urbanairship.com/api/user/userName/"]) {
            return NO;
        }

        NSString *requestString = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
        id data = [NSJSONSerialization objectWithString:requestString];
        return [expectedRequestBody isEqualToDictionary:data];
    };


    // Verify we add a channel ID and remove the device token if they are both present
    expectedRequestBody = @{@"ios_channels": @{@"add" : @[@"channel"]}};
    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];



    [self.client updateUser:self.mockUser
                  channelID:@"channel"
                  onSuccess:^{}
                  onFailure:^(UAHTTPRequest *request) {}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should make a create user request.");

    
    // Verify we only add a channel ID if there is no device token
    expectedRequestBody = @{@"ios_channels": @{@"add" : @[@"channel"]}};
    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [self.client updateUser:self.mockUser
                  channelID:@"channel"
                  onSuccess:^{}
                  onFailure:^(UAHTTPRequest *request) {}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Create user should make a create user request.");
}



@end
