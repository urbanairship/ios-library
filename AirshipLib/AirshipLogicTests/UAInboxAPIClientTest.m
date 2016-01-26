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

@property (nonatomic, strong) UAConfig *config;

@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andReturn:@"userName"] username];
    [[[self.mockUser stub] andReturn:@"userPassword"] password];

    self.inboxAPIClient = [UAInboxAPIClient clientWithUser:self.mockUser
                                                    config:self.mockConfig
                                                 dataStore:self.mockDataStore];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockPush stopMocking];
    [self.mockUser stopMocking];
    [self.mockDataStore stopMocking];

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
- (void) testRequestToPerformBatchMarkReadForMessages {

    NSArray *mockMessages = [NSArray array];

    // Test with nil channel ID
    NSDictionary *requestHeaders = [self.inboxAPIClient requestToPerformBatchMarkReadForMessages:mockMessages].headers;

    XCTAssertNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be not present.");

    // Test with mocked channel ID
    [[[self.mockPush stub] andReturn:@"mockChannelID"] channelID];

    requestHeaders = [self.inboxAPIClient requestToPerformBatchMarkReadForMessages:mockMessages].headers;

    XCTAssertNotNil([requestHeaders objectForKey:kUAChannelIDHeader], @"Channel ID header should be present.");
}

@end
