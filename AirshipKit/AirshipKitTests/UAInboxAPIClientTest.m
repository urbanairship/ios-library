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

#import "UAConfig+Internal.h"
#import "UAirship+Internal.h"
#import "UAPush+Internal.h"
#import "UAUser+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInboxAPIClient+Internal.h"

@interface UAInboxAPIClientTest : XCTestCase

@property (nonatomic, strong) UAInboxAPIClient *inboxAPIClient;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) id mockDataStore;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockSession;

@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andReturn:@"userName"] username];
    [[[self.mockUser stub] andReturn:@"userPassword"] password];

    self.inboxAPIClient = [UAInboxAPIClient clientWithConfig:self.mockConfig
                                                     session:self.mockSession
                                                        user:self.mockUser
                                                   dataStore:self.mockDataStore];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockPush stopMocking];
    [self.mockUser stopMocking];
    [self.mockDataStore stopMocking];
    [self.mockSession stopMocking];

    [super tearDown];
}

/**
 * Test retrieve message request contains channel header when channel ID is present.
 */
- (void)testRequestToRetrieveMessageList {

    // Test with nil channel ID
    NSDictionary *requestHeaders = [self.inboxAPIClient requestToRetrieveMessageList].headers;

    XCTAssertNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be not present.");

    // Test with mocked channel ID
    [[[self.mockPush stub] andReturn:@"mockChannelID"] channelID];

    requestHeaders = [self.inboxAPIClient requestToRetrieveMessageList].headers;

    XCTAssertNotNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be present.");

    [[[self.mockPush stub] andReturn:nil] channelID];

    requestHeaders = [self.inboxAPIClient requestToRetrieveMessageList].headers;

}

/**
 * Test batch delete request contains channel header when channel ID is present.
 */
- (void)testRequestToPerformBatchDeleteForMessages {

    NSArray *mockMessages = [NSArray array];

    // Test with nil channel ID
    NSDictionary *requestHeaders = [self.inboxAPIClient requestToPerformBatchDeleteForMessages:mockMessages].headers;

    XCTAssertNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be not present.");

    // Test with mocked channel ID
    [[[self.mockPush stub] andReturn:@"mockChannelID"] channelID];

    requestHeaders = [self.inboxAPIClient requestToPerformBatchDeleteForMessages:mockMessages].headers;

    XCTAssertNotNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be present.");
}

/**
 * Test batch mark read request contains channel header when channel ID is present.
 */
- (void)testRequestToPerformBatchMarkReadForMessages {

    NSArray *mockMessages = [NSArray array];

    // Test with nil channel ID
    NSDictionary *requestHeaders = [self.inboxAPIClient requestToPerformBatchMarkReadForMessages:mockMessages].headers;

    XCTAssertNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be not present.");

    // Test with mocked channel ID
    [[[self.mockPush stub] andReturn:@"mockChannelID"] channelID];

    requestHeaders = [self.inboxAPIClient requestToPerformBatchMarkReadForMessages:mockMessages].headers;

    XCTAssertNotNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be present.");
}

/**
 * Tests retrieving the message list on success.
 */
- (void)testRetrieveMessageListOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true, \"messages\": [\"someMessage\"]}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Make call
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTAssertEqualObjects(messages[0], @"someMessage", @"Messages should match messages from the response");
    } onFailure:^(NSUInteger status) {
        XCTFail(@"Should not be called");
    }];

    [self.mockSession verify];
    [self.mockSession stopMocking];
}

/**
 * Tests retrieving the message list on failure.
 */
- (void)testRetrieveMessageListOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSUInteger failureCode = 0;
    [self.inboxAPIClient retrieveMessageListOnSuccess:^(NSUInteger status, NSArray * _Nullable messages) {
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger status) {
        failureCode = status;
    }];

    XCTAssertTrue(failureCode == 500);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}

/**
 * Tests batch mark as read on success.
 */
- (void)testBatchMarkAsReadOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL successBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchMarkAsReadForMessages:@[@{@"messageURL":testURL}] onSuccess:^{
        successBlockCalled = true;
    } onFailure:^(NSUInteger status) {
        XCTFail(@"Should not be called");
    }];

    XCTAssertTrue(successBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}

/**
 * Tests batch mark as read on failure.
 */
- (void)testBatchMarkAsReadOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL failureBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchMarkAsReadForMessages:@[@{@"messageURL":testURL}] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger status) {
        failureBlockCalled = true;
    }];

    XCTAssertTrue(failureBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}

/**
 * Tests batch delete on success.
 */
- (void)testBatchDeleteOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(responseData, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL successBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchDeleteForMessages:@[@{@"messageURL":testURL}] onSuccess:^{
        successBlockCalled = true;
    } onFailure:^(NSUInteger status) {
        XCTFail(@"Should not be called");
    }];

    XCTAssertTrue(successBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}

/**
 * Tests batch delete on failure.
 */
- (void)testBatchDeleteOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;

        completionHandler(nil, (NSURLResponse *)response, nil);

        typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSURL *testURL = [NSURL URLWithString:@"testURL"];
    __block BOOL failureBlockCalled = false;

    // Make call
    [self.inboxAPIClient performBatchDeleteForMessages:@[@{@"messageURL":testURL}] onSuccess:^{
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger status) {
        failureBlockCalled = true;
    }];

    XCTAssertTrue(failureBlockCalled);

    [self.mockSession verify];
    [self.mockSession stopMocking];
}


@end
