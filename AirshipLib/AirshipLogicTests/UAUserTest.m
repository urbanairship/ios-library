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

#import <XCTest/XCTest.h>
#import "UAUser+Internal.h"
#import "UAUserAPIClient.h"
#import "UAUserData.h"
#import "UAKeychainUtils.h"
#import "UAPush+Internal.h"
#import "UAirship+Internal.h"
#import "UAConfig+Internal.h"
#import "UAPreferenceDataStore.h"

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

@interface UAUserTest : XCTestCase
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAConfig *config;

@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) id mockUserClient;
@property (nonatomic, strong) id mockKeychainUtils;
@property (nonatomic, strong) id mockApplication;

@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];

    self.config = [[UAConfig alloc] init];
    self.config.developmentAppKey = @"9Q1tVTl0RF16baYKYp8HPQ";
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"user.test."];
    self.push = [UAPush pushWithConfig:self.config dataStore:self.dataStore];


    [[[NSBundle mainBundle] infoDictionary] setValue:@"someBundleID" forKey:@"CFBundleIdentifier"];
    self.mockKeychainUtils = [OCMockObject niceMockForClass:[UAKeychainUtils class]];

    self.user = [UAUser userWithPush:self.push config:self.config dataStore:self.dataStore];
    self.mockUserClient = [OCMockObject partialMockForObject:self.user.apiClient];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
 }

- (void)tearDown {
    [self.mockUserClient stopMocking];
    [self.mockKeychainUtils stopMocking];
    [self.mockApplication stopMocking];
    [self.dataStore removeAll];

    [super tearDown];
}

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values
    XCTAssertNotNil(self.user, @"we should at least have a user");
    XCTAssertNil(self.user.username, @"user name should be nil");
    XCTAssertNil(self.user.password, @"password should be nil");
    XCTAssertNil(self.user.url, @"url should be nil");
}

- (void)testIsCreated {
    XCTAssertFalse(self.user.isCreated, @"Uninitialized user should not be created");
}

/**
 * Test createUser when the request is successful
 */
-(void)testCreateUserSuccessful {
    __block UAUserAPIClientCreateSuccessBlock successBlock;

    UAUserData *userData = [UAUserData dataWithUsername:@"userName" password:@"password" url:@"http://url.com"];


    self.push.channelID = @"some-channel";
    self.push.channelLocation = @"some-location";
    self.push.deviceToken = nil;

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        successBlock = (__bridge UAUserAPIClientCreateSuccessBlock)arg;
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:@"some-channel"
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Expect it to create and update the keychain
    [[[self.mockKeychainUtils expect] andReturnValue:OCMOCK_VALUE(YES)] createKeychainValueForUsername:userData.username
                                                                                          withPassword:userData.password
                                                                                         forIdentifier:self.config.appKey];

    [[[self.mockKeychainUtils expect] andReturnValue:OCMOCK_VALUE(YES)] updateKeychainValueForUsername:userData.username
                                                                                          withPassword:userData.password
                                                                                         forIdentifier:self.config.appKey];

    [self.user createUser];

    // Should be creating the user before the success is called
    XCTAssertTrue(self.user.creatingUser, @"Should be creating user before the success block is called");

    // Call the success block
    successBlock(userData, @{});

    XCTAssertFalse(self.user.creatingUser, @"Should be finished creating user after the success block is called");
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created");
    XCTAssertEqualObjects(self.user.username, userData.username, @"Username should be set when user created successfully.");
    XCTAssertEqualObjects(self.user.password, userData.password, @"Password should be set when user created successfully.");
    XCTAssertEqualObjects(self.user.url, userData.url, @"URL should be set when user created successfully.");
}

/**
 * Test createUser when the request fails
 */
-(void)testCreateUserFailed {
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    self.push.channelID = @"some-channel";
    self.push.channelLocation = @"some-channel-location";

    __block UAUserAPIClientFailureBlock failureBlock;

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        failureBlock = (__bridge UAUserAPIClientFailureBlock)arg;
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:@"some-channel"
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.user createUser];

    XCTAssertTrue(self.user.creatingUser, @"Should be creating user before the success block is called.");
    failureBlock(request);
    XCTAssertFalse(self.user.creatingUser, @"Should be finished creating user after the success block is called.");
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created.");
}


/**
 * Test updateUser
 */
-(void)testUpdateUser {
    self.push.channelID = @"some-channel";
    self.push.channelLocation = @"some-location";
    self.push.deviceToken = @"aaaaa";

    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    [[self.mockUserClient expect] updateUser:self.user
                                 deviceToken:@"aaaaa"
                                   channelID:@"some-channel"
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.user updateUser];
    
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");
}

/**
 * Test updateUser when no device token or channel ID is present
 */
-(void)testUpdateUserNoDeviceTokenOrChannelID {
    self.push.channelID = nil;
    self.push.deviceToken = nil;

    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user updateUser];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should not update if the device token and channel ID is missing.");
}


/**
 * Test updateUser no default user
 */
-(void)testUpdateUserNoDefaultUser {
    self.push.channelID = @"some-channel";
    self.push.deviceToken = @"aaaaa";
    self.user.username = @"username";

    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user updateUser];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should not update if a default user is not created yet.");
}


/**
 * Test registering as an observer for UAPush registration changes
 * calls update if the channel is available.
 */
-(void)testRegisterForDeviceRegistrationChangesChannelIDAvailable {
    self.push.channelID = @"some-channel";
    self.push.channelLocation = @"some-location";
    self.push.deviceToken = @"aaaaa";

    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    // Expect an update call when we register for device registration changes
    [[self.mockUserClient expect] updateUser:self.user
                                 deviceToken:@"aaaaa"
                                   channelID:@"some-channel"
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.user unregisterForDeviceRegistrationChanges];
    [self.user registerForDeviceRegistrationChanges];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");
}


/**
 * Test unregistering as an observer for UAPush registration changes
 */
-(void)testUnregisterForDeviceRegistrationChanges {
    [self.user registerForDeviceRegistrationChanges];
    id mockPush = [OCMockObject partialMockForObject:self.push];

    XCTAssertTrue(self.user.isObservingDeviceRegistrationChanges, @"We should be observing registration changes after registeringForDeviceRegistrationChanges.");

    [[mockPush expect] removeObserver:self.user forKeyPath:@"channelID"];

    [self.user unregisterForDeviceRegistrationChanges];

    XCTAssertFalse(self.user.isObservingDeviceRegistrationChanges, @"We should not be observing registration changes after unregisteringForDeviceRegistrationChanges.");
    XCTAssertNoThrow([mockPush verify], @"User should remove itself as an observer for device token and channel ID.");

    [[mockPush reject] removeObserver:self.user forKeyPath:@"channelID"];
    [self.user unregisterForDeviceRegistrationChanges];

    XCTAssertNoThrow([mockPush verify], @"User should not be able to unregister twice for KVO.");
    [mockPush stopMocking];
}

/**
 * Test observer changes to channel ID updates the user
 */
-(void)testObserveValueForKeyPath {
    self.push.channelID = @"some-channel";
    self.push.channelLocation = @"some-location";
    self.push.deviceToken = @"aaaaa";
    
    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    [[self.mockUserClient expect] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.user observeValueForKeyPath:@"channelID" ofObject:nil change:nil context:nil];

    // Change the channel ID
    self.push.channelID = @"channelID";

    XCTAssertNoThrow([self.mockUserClient verify]);
}

@end
