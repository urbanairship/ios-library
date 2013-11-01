/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAUser+Internal.h"
#import "UAUserAPIClient.h"
#import "UAUserData.h"
#import "UAKeychainUtils.h"
#import "UAPush+Internal.h"
#import "UAirship+Internal.h"

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

@interface UAUserTest : XCTestCase
@property(nonatomic, strong) UAUser *user;
@property(nonatomic, strong) id mockUserClient;
@property(nonatomic, strong) id mockKeychainUtils;
@property(nonatomic, strong) id mockedAirship;
@property(nonatomic, strong) id mockedUAPush;
@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];
    self.user = [[UAUser alloc] init];

    self.mockedAirship =[OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];

    self.mockUserClient = [OCMockObject partialMockForObject:self.user.apiClient];
    self.mockKeychainUtils = [OCMockObject niceMockForClass:[UAKeychainUtils class]];

    self.mockedUAPush = [OCMockObject partialMockForObject:[UAPush shared]];

    // set an app key to allow the keychain utils to look for a username
    self.user.appKey = @"9Q1tVTl0RF16baYKYp8HPQ";
}

- (void)tearDown {
    [self.mockUserClient stopMocking];
    [self.mockKeychainUtils stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockedUAPush stopMocking];

    [super tearDown];
}

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values
    XCTAssertNotNil(self.user, @"we should at least have a user");
    XCTAssertNil(self.user.username, @"user name should be nil");
    XCTAssertNil(self.user.password, @"password should be nil");
    XCTAssertNil(self.user.url, @"url should be nil");
}

- (void)testDefaultUserCreated {
    XCTAssertFalse([self.user defaultUserCreated], @"Uninitialized user should not be created");
}

/**
 * Test createUser when the request is successful
 */
-(void)testCreateUserSuccessful {
    __block UAUserAPIClientCreateSuccessBlock successBlock;

    UAUserData *userData = [UAUserData dataWithUsername:@"userName" password:@"password" url:@"http://url.com"];

    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = nil;

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        successBlock = (__bridge UAUserAPIClientCreateSuccessBlock)arg;
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:@"some-channel"
                                                                 deviceToken:nil
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];

    // Expect it to create and update the keychain
    [[[self.mockKeychainUtils expect] andReturnValue:OCMOCK_VALUE(YES)] createKeychainValueForUsername:userData.username
                                                                                          withPassword:userData.password
                                                                                         forIdentifier:self.user.appKey];

    [[[self.mockKeychainUtils expect] andReturnValue:OCMOCK_VALUE(YES)] updateKeychainValueForUsername:userData.username
                                                                                          withPassword:userData.password
                                                                                         forIdentifier:self.user.appKey];

    [self.user createUser];

    // Should be creating the user before the success is called
    XCTAssertTrue(self.user.creatingUser, @"Should be creating user before the success block is called");

    // Call the success block
    successBlock(userData, @{});

    XCTAssertFalse(self.user.creatingUser, @"Should be finished creating user after the success block is called");
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created");
    XCTAssertEqual(self.user.username, userData.username, @"Username should be set when user created successfully.");
    XCTAssertEqual(self.user.password, userData.password, @"Password should be set when user created successfully.");
    XCTAssertEqual(self.user.url, userData.url, @"URL should be set when user created successfully.");
}

/**
 * Test createUser when the request fails
 */
-(void)testCreateUserFailed {
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = nil;

    __block UAUserAPIClientFailureBlock failureBlock;

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        failureBlock = (__bridge UAUserAPIClientFailureBlock)arg;
    };

    [UAPush shared].channelID = @"some-channel";

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:@"some-channel"
                                                                 deviceToken:nil
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];
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
    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = @"aaaaa";
    self.user.username = @"username";

    // Set up a default user
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] ready];
    [[[self.mockKeychainUtils stub] andReturn:@"username"] getUsername:self.user.appKey];
    [[[self.mockKeychainUtils stub] andReturn:@"password"] getPassword:self.user.appKey];

    [[self.mockUserClient expect] updateUser:@"username"
                                 deviceToken:@"aaaaa"
                                   channelID:@"some-channel"
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user updateUser];
    
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");
}

/**
 * Test updateUser when no device token or channel id is present
 */
-(void)testUpdateUserNoDeviceTokenOrChannelID {
    [UAPush shared].channelID = nil;
    [UAPush shared].deviceToken = nil;
    self.user.username = @"username";

    // Set up a default user
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] ready];
    [[[self.mockKeychainUtils stub] andReturn:@"username"] getUsername:self.user.appKey];
    [[[self.mockKeychainUtils stub] andReturn:@"password"] getPassword:self.user.appKey];

    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user updateUser];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should not update if the device token and channel id is missing.");
}


/**
 * Test updateUser no default user
 */
-(void)testUpdateUserNoDefaultUser {
    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = @"aaaaa";
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
 */
-(void)testRegisterForDeviceRegistrationChanges {
    XCTAssertFalse(self.user.isObservingDeviceRegistrationChanges, @"We should not be observing registration changes initially.");

    [[self.mockedUAPush expect] addObserver:self.user forKeyPath:@"deviceToken" options:0 context:NULL];
    [[self.mockedUAPush expect] addObserver:self.user forKeyPath:@"channelID" options:0 context:NULL];

    [self.user registerForDeviceRegistrationChanges];

    XCTAssertTrue(self.user.isObservingDeviceRegistrationChanges, @"We should be observing registration changes after registeringForDeviceRegistrationChanges.");
    XCTAssertNoThrow([self.mockedUAPush verify], @"User should add itself as an observer for device token and channel ID.");

    [[self.mockedUAPush reject] addObserver:self.user forKeyPath:@"deviceToken" options:0 context:NULL];
    [[self.mockedUAPush reject] addObserver:self.user forKeyPath:@"channelID" options:0 context:NULL];
    [self.user registerForDeviceRegistrationChanges];

    XCTAssertNoThrow([self.mockedUAPush verify], @"User should not be able to register twice for KVO.");

}

/**
 * Test registering as an observer for UAPush registration changes
 * calls update if the channel or device token is available.
 */
-(void)testRegisterForDeviceRegistrationChangesChannelIDAvailable {
    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = @"aaaaa";
    self.user.username = @"username";

    // Set up a default user
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] ready];
    [[[self.mockKeychainUtils stub] andReturn:@"username"] getUsername:self.user.appKey];
    [[[self.mockKeychainUtils stub] andReturn:@"password"] getPassword:self.user.appKey];

    // Expect an update call when we register for device registration changes
    [[self.mockUserClient expect] updateUser:@"username"
                                 deviceToken:@"aaaaa"
                                   channelID:@"some-channel"
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];


    [self.user registerForDeviceRegistrationChanges];
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");
}


/**
 * Test unregistering as an observer for UAPush registration changes
 */
-(void)testUnregisterForDeviceRegistrationChanges {
    [self.user registerForDeviceRegistrationChanges];

    XCTAssertTrue(self.user.isObservingDeviceRegistrationChanges, @"We should be observing registration changes after registeringForDeviceRegistrationChanges.");

    [[self.mockedUAPush expect] removeObserver:self.user forKeyPath:@"deviceToken"];
    [[self.mockedUAPush expect] removeObserver:self.user forKeyPath:@"channelID"];

    [self.user unregisterForDeviceRegistrationChanges];

    XCTAssertFalse(self.user.isObservingDeviceRegistrationChanges, @"We should not be observing registration changes after unregisteringForDeviceRegistrationChanges.");
    XCTAssertNoThrow([self.mockedUAPush verify], @"User should remove itself as an observer for device token and channel ID.");

    [[self.mockedUAPush reject] removeObserver:self.user forKeyPath:@"deviceToken"];
    [[self.mockedUAPush reject] removeObserver:self.user forKeyPath:@"channelID"];
    [self.user unregisterForDeviceRegistrationChanges];

    XCTAssertNoThrow([self.mockedUAPush verify], @"User should not be able to unregister twice for KVO.");
}

/**
 * Test observer changes to device token and channel ID updates the user
 */
-(void)testObserveValueForKeyPath {
    [UAPush shared].channelID = @"some-channel";
    [UAPush shared].deviceToken = @"aaaaa";
    self.user.username = @"username";

    // Set up a default user
    [[[self.mockedAirship stub] andReturnValue:OCMOCK_VALUE(YES)] ready];
    [[[self.mockKeychainUtils stub] andReturn:@"username"] getUsername:self.user.appKey];
    [[[self.mockKeychainUtils stub] andReturn:@"password"] getPassword:self.user.appKey];


    [[self.mockUserClient expect] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user observeValueForKeyPath:@"channelID" ofObject:nil change:nil context:nil];
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");

    [UAPush shared].channelID = nil;
    [[self.mockUserClient expect] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user observeValueForKeyPath:@"deviceToken" ofObject:nil change:nil context:nil];
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");


    // Device token changes should be ignored if we have a channel id
    [UAPush shared].channelID = @"channelID";
    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                 deviceToken:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user observeValueForKeyPath:@"deviceToken" ofObject:nil change:nil context:nil];
    XCTAssertNoThrow([self.mockUserClient verify], @"User should not call the client to be updated on device token changes if we have a channel ID.");
}

@end