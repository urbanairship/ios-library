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
#import <OCMock/OCMock.h>
#import "UAUserAPIClient+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUtils.h"
#import "UAConfig+Internal.h"
#import "UAirship+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"


@interface UAUserAPIClientTest : XCTestCase
@property (nonatomic, strong) UAUserAPIClient *client;
@property (nonatomic, strong) id mockRequest;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockUser;

@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAUserAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];

    self.mockRequest = [OCMockObject niceMockForClass:[UARequest class]];
    self.client = [UAUserAPIClient clientWithConfig:self.config session:self.mockSession];

    self.mockUAUtils = [OCMockObject niceMockForClass:[UAUtils class]];
    [[[self.mockUAUtils stub] andReturn:@"deviceID"] deviceID];

    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andReturn:@"userName"] username];
    [[[self.mockUser stub] andReturn:@"userPassword"] password];
}

- (void)tearDown {
    [self.mockRequest stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUser stopMocking];
    [self.mockSession stopMocking];

    [super tearDown];
}

/**
 * Test create user retry
 */
-(void)testCreateUserRetry {
    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(OCMOCK_ANY, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(OCMOCK_ANY, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   XCTFail(@"Should not be called");
                               }
                               onFailure:^(NSUInteger statusCode){
                                   XCTFail(@"Should not be called");
                               }];


    XCTAssertNoThrow([self.mockSession verify], @"Create user should call retry on 5xx status codes");
}

/**
 * Test create user success
 */
-(void)testCreateUserSuccess {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [NSJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block UAUserData *successData;

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   successData = data;
                               }
                               onFailure:^(NSUInteger statusCode){
                                   XCTFail(@"Should not be called");
                               }];

    XCTAssertNoThrow([self.mockSession verify], @"Create user should succeed on 201.");

    XCTAssertEqualObjects(successData.username, [responseDict valueForKey:@"user_id"]);
    XCTAssertEqualObjects(successData.password, [responseDict valueForKey:@"password"]);
    XCTAssertEqualObjects(successData.url, [responseDict valueForKey:@"user_url"]);
}

/**
 * Test create user failure
 */
-(void)testCreateUserFailure {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [NSJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block NSUInteger failureStatusCode = 0;

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   XCTFail(@"Should not be called");
                               }
                               onFailure:^(NSUInteger statusCode){
                                   failureStatusCode = statusCode;
                               }];

    XCTAssertNoThrow([self.mockSession verify], @"Create user should fail on 400.");

    XCTAssertEqual(failureStatusCode, 400);
}

/**
 * Test create user request with a channel ID
 */
-(void)testCreateUserRequestChannelID {
    NSDictionary *expectedRequestBody = @{@"ua_device_id": @"deviceID", @"ios_channels": @[@"channelID"]};

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/"]) {
            return NO;
        }

        // Check that it's a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // Check that it contains an accept header
        if (![[request.headers valueForKey:@"Accept"] isEqualToString:@"application/vnd.urbanairship+json; version=3;"]) {
            return NO;
        }

        // Check that it contains an content type header
        if (![[request.headers valueForKey:@"Content-Type"] isEqualToString:@"application/json"]) {
            return NO;
        }

        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:expectedRequestBody options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];


    [self.client createUserWithChannelID:@"channelID" onSuccess:^(UAUserData * _Nonnull data, NSDictionary * _Nonnull payload) {
    } onFailure:^(NSUInteger statusCode) {
    }];
    
    [self.mockSession verify];
}

/**
 * Test update user retry
 */
-(void)testUpdateUserRetry {
    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(OCMOCK_ANY, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(OCMOCK_ANY, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      XCTFail(@"Should not be called");
                  }
                  onFailure:^(NSUInteger statusCode){
                      XCTFail(@"Should not be called");
                  }];


    XCTAssertNoThrow([self.mockSession verify], @"Update user should call retry on 5xx status codes");
}

/**
 * Test update user success
 */
-(void)testUpdateUserSuccess {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [NSJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block BOOL successBlockCalled = false;

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      successBlockCalled = YES;
                  }
                  onFailure:^(NSUInteger statusCode){
                      XCTFail(@"Should not be called");
                  }];

    XCTAssertNoThrow([self.mockSession verify], @"Update user should succeed on 200.");

    XCTAssertTrue(successBlockCalled);
}

/**
 * Test update user failure
 */
-(void)testUpdateUserFailure {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [NSJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block NSUInteger failureStatusCode = 0;

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      XCTFail(@"Should not be called");
                  }
                  onFailure:^(NSUInteger statusCode){
                      failureStatusCode = statusCode;
                  }];

    XCTAssertNoThrow([self.mockSession verify], @"Update user should fail on 400.");

    XCTAssertEqual(failureStatusCode, 400);
}

/**
 * Test update user request payload adds the right things.
 */
-(void)testUpdateUserRequest {
    NSDictionary *expectedRequestBody = @{@"ios_channels": @{@"add" : @[@"channelID"]}};


    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/userName/"]) {
            return NO;
        }

        // Check that it's a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // Check that it contains an accept header
        if (![[request.headers valueForKey:@"Accept"] isEqualToString:@"application/vnd.urbanairship+json; version=3;"]) {
            return NO;
        }

        // Check that it contains an content type header
        if (![[request.headers valueForKey:@"Content-Type"] isEqualToString:@"application/json"]) {
            return NO;
        }

        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:expectedRequestBody options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateUser:self.mockUser channelID:@"channelID" onSuccess:^(UAUserData * _Nonnull data, NSDictionary * _Nonnull payload) {
    } onFailure:^(NSUInteger statusCode) {
    }];
    
    [self.mockSession verify];
}

@end
