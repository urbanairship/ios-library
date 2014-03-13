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
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UADeviceAPIClient.h"
#import "UAChannelAPIClient.h"
#import "UADeviceRegistrar+Internal.h"
#import "UAChannelRegistrationPayload.h"
#import "UAHTTPRequest+Internal.h"

@interface UADeviceRegistrarTest : XCTestCase
@property(nonatomic, strong) id mockedApplication;
@end

@implementation UADeviceRegistrarTest

id mockedDeviceClient;
id mockedChannelClient;
id mockedRegistrarDelegate;

void (^channelUpdateSuccessDoBlock)(NSInvocation *);
void (^channelCreateSuccessDoBlock)(NSInvocation *);
void (^channelUpdateFailureDoBlock)(NSInvocation *);
void (^channelCreateFailureDoBlock)(NSInvocation *);

void (^deviceRegisterSuccessDoBlock)(NSInvocation *);

UAHTTPRequest *deviceFailureRequest;
UAHTTPRequest *channelFailureRequest;
NSString *channelCreateSuccessChannelID;
NSString *channelCreateSuccessChannelLocation;


UAChannelRegistrationPayload *payload;
UADeviceRegistrar *registrar;


- (void)setUp {
    [super setUp];

    // Set up a mocked application
    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];


    channelCreateSuccessChannelID = @"newChannelID";
    channelCreateSuccessChannelLocation = @"newChannelLocation";

    mockedDeviceClient = [OCMockObject niceMockForClass:[UADeviceAPIClient class]];
    mockedChannelClient = [OCMockObject niceMockForClass:[UAChannelAPIClient class]];

    mockedRegistrarDelegate = [OCMockObject niceMockForProtocol:@protocol(UADeviceRegistrarDelegate)];

    registrar = [[UADeviceRegistrar alloc] init];
    registrar.deviceAPIClient = mockedDeviceClient;
    registrar.channelAPIClient = mockedChannelClient;
    registrar.delegate = mockedRegistrarDelegate;

    payload = [[UAChannelRegistrationPayload alloc] init];
    payload.pushAddress = @"someDeviceToken";

    channelFailureRequest = [[UAHTTPRequest alloc] init];
    deviceFailureRequest = [[UAHTTPRequest alloc] init];

    channelUpdateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientUpdateSuccessBlock successBlock = (__bridge UAChannelAPIClientUpdateSuccessBlock)arg;
        successBlock();
    };

    channelUpdateFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAChannelAPIClientFailureBlock failureBlock = (__bridge UAChannelAPIClientFailureBlock)arg;
        failureBlock(channelFailureRequest);
    };

    channelCreateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAChannelAPIClientCreateSuccessBlock successBlock = (__bridge UAChannelAPIClientCreateSuccessBlock)arg;
        successBlock(channelCreateSuccessChannelID, channelCreateSuccessChannelLocation);
    };

    channelCreateFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientFailureBlock failureBlock = (__bridge UAChannelAPIClientFailureBlock)arg;
        failureBlock(channelFailureRequest);
    };

    deviceRegisterSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock)arg;
        successBlock();
    };
}


- (void)tearDown {
    [super tearDown];
    
    [mockedDeviceClient stopMocking];
    [mockedChannelClient stopMocking];
    [mockedRegistrarDelegate stopMocking];
}

/**
 * Test sucessful register with a channel
 */
- (void)testRegisterWithChannel {
    // Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    // Background task should be ended
    [[self.mockedApplication expect] endBackgroundTask:30];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called.");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the start and end a background task");
}

/**
 * Test failed register with a channnel
 */
- (void)testRegisterWithChannelFail {
    // Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    // Expect a background task to be created and ended
    [[self.mockedApplication expect] endBackgroundTask:30];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on failure");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the start and end a background task");
}

/**
 * Test register with a channel ID with the same payload as the last successful
 * registration payload.
 */
- (void)testRegisterWithChannelDuplicate {
    // Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Add a successful request
    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    // Expect it again when we call run it forcefully
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    // Run it again forcefully
    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forcefully should not care about previous requests.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called");


    // Run it normally, it should not call update
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    // Delegate should still be called
    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:payload];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on success");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
}

/**
 * Test register without a channel creates a channel
 */
- (void)testRegisterNoChannel {
    // Expect the channel client to create a channel and call success block
    [[[mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];
    [[mockedRegistrarDelegate expect] channelCreated:channelCreateSuccessChannelID channelLocation:channelCreateSuccessChannelLocation];


    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device should clear any pending requests");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on success");
}

/**
 * Test that registering registering when a request is in progress 
 * does not attempt to register again
 */
- (void)testRegisterRequestInProgress {
    // Expect the channel client to create a channel and not call either block so the
    // request stays pending
    [[mockedChannelClient expect] createChannelWithPayload:OCMOCK_ANY
                                                 onSuccess:OCMOCK_ANY
                                                 onFailure:OCMOCK_ANY];

    // Make a pending request
    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    // Reject any registration requests
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[mockedChannelClient reject] createChannelWithPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[mockedDeviceClient reject] registerDeviceToken:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[mockedDeviceClient reject] unregisterDeviceToken:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    XCTAssertNoThrow([registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"A pending request should ignore any further requests.");
    XCTAssertNoThrow([registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:YES], @"A pending request should ignore any further requests.");
    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"A pending request should ignore any further requests.");
    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:YES], @"A pending request should ignore any further requests.");
}

/**
 * Test a succesful register when push is disabled with a channel
 */
- (void)testRegisterPushDisabledWithChannel {
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];


    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on success");
}

/**
 * Test a failed register when push is disabled with a channel
 */
- (void)testRegisterPushDisabledWithChannelFail {
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];
    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    // Background task should be ended
    [[self.mockedApplication expect] endBackgroundTask:30];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on failure");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the start and end a background task");
}


/**
 * Test register push disabled with the same payload as the
 * previous successful payload.
 */
- (void)testRegisterPushDisabledWithChannelDuplicate {
    // Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Add a successful request
    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    // Expect it again when we call run it forcefully
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];




    // Run it again forcefully
    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forcefully should not care about previous requests.");


    // Run it normally, it should not call update
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];


    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip.");
}

/**
 * Test that register push disabeld without a channel attempts to create a channel
 */
- (void)testRegisterPushDisabledNoChannelID {
    // Expect the channel client to create a channel and call success block
    [[[mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    // Background task should be ended
    [[self.mockedApplication expect] endBackgroundTask:30];

    [registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should end the start and end a background task");
}

/**
 * Test that registering with a nil channel id first tries to create a channel 
 * and falls back to registering the device token.
 */
- (void)testRegisterNoChannelFallback {
    payload.pushAddress = @"some-device-token";
    registrar.isDeviceTokenRegistered  = NO;

    // Set up failure with 501 so we fallback
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:501 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to create a channel and fail with 501
    [[[mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[[mockedDeviceClient expect] andDo:deviceRegisterSuccessDoBlock] registerDeviceToken:payload.pushAddress
                                                                              withPayload:OCMOCK_ANY
                                                                                onSuccess:OCMOCK_ANY
                                                                                onFailure:OCMOCK_ANY];

    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to register the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertFalse(registrar.isUsingChannelRegistration, @"Failing to create a channel with a 501 should fallback to device token registration");

    // Reject any more unregister calls
    [[mockedDeviceClient reject] registerDeviceToken:OCMOCK_ANY
                                         withPayload:OCMOCK_ANY
                                           onSuccess:OCMOCK_ANY
                                           onFailure:OCMOCK_ANY];

    XCTAssertNoThrow( [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not register the device token twice");


    payload.pushAddress = nil;
    registrar.isDeviceTokenRegistered  = NO;
    XCTAssertNoThrow([registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not try to register a nil device token");
}

/**
 * Test device fallback when trying to register push disabled.
 */
- (void)testRegisterPushDisabledNoChannelFallback {
    payload.pushAddress = @"some-device-token";
    registrar.isDeviceTokenRegistered  = NO;

    // Set up failure with 501 so we fallback
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:501 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to create a channel and fail with 501
    [[[mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[[mockedDeviceClient expect] andDo:deviceRegisterSuccessDoBlock] registerDeviceToken:payload.pushAddress
                                                                              withPayload:OCMOCK_ANY
                                                                                onSuccess:OCMOCK_ANY
                                                                                onFailure:OCMOCK_ANY];

    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to register the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on success");
    XCTAssertFalse(registrar.isUsingChannelRegistration, @"Failing to create a channel with a 501 should fallback to device token registration");

    // Reject any more unregister calls
    [[mockedDeviceClient reject] registerDeviceToken:OCMOCK_ANY
                                         withPayload:OCMOCK_ANY
                                           onSuccess:OCMOCK_ANY
                                           onFailure:OCMOCK_ANY];

    XCTAssertNoThrow( [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not register the device token twice");


    payload.pushAddress = nil;
    registrar.isDeviceTokenRegistered  = NO;
    XCTAssertNoThrow([registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not try to register a nil device token");
}

/**
 * Test cancelAllRequests
 */
- (void)testCancelAllRequests {
    registrar.lastSuccessPayload = [[UAChannelRegistrationPayload alloc] init];
    registrar.isRegistrationInProgress = NO;
    [[mockedChannelClient expect] cancelAllRequests];
    [[mockedDeviceClient expect] cancelAllRequests];

    [registrar cancelAllRequests];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should cancel all of its requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should cancel all of its requests.");
    XCTAssertNotNil(registrar.lastSuccessPayload, @"Last success payload should not be cleared if a request is not in progress.");

    registrar.isRegistrationInProgress = YES;
    [[mockedChannelClient expect] cancelAllRequests];
    [[mockedDeviceClient expect] cancelAllRequests];

    [registrar cancelAllRequests];
    XCTAssertNil(registrar.lastSuccessPayload, @"Last success payload should be cleared if a request is in progress.");
    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should cancel all of its requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should cancel all of its requests.");
}

/**
 * Test that a channel update with a 409 status tries to 
 * create a new channel id.
 */
- (void)testChannelConflictNewChannel {
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:409 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the create channel to be called, make it successful
    channelCreateSuccessChannelID = @"newChannel";
    [[[mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];
    [[mockedRegistrarDelegate expect] channelCreated:@"newChannel" channelLocation:channelCreateSuccessChannelLocation];


    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Conflict with the channel id should create a new channel");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Registration delegate should be called with the new channel");
}

/**
 * Test that a channel update with a 409 fails to create a new
 * channel.
 */
- (void)testChannelConflictFailed {
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:409 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the create channel to be called, make it fail
    [[[mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];



    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Conflict with the channel id should try to create a new channel");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on failure");
}

/**
 * Test that when a background task is unable to be created registration is aborted.f
 */
- (void)testRegisterBackgroundTaskInvalid {
    [self.mockedApplication stopMocking];

    self.mockedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    [[[self.mockedApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Reject the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannelWithLocation:@"someLocation"
                                                 withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                   onSuccess:OCMOCK_ANY
                                                   onFailure:OCMOCK_ANY];


    // Expect the delegate to be called
    [[mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];

    XCTAssertNoThrow([mockedChannelClient verify], @"Should not register when an invalid background task ID is returned.");
    XCTAssertNoThrow([self.mockedApplication verify], @"Should request a background task.");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Delegate should be called on failure");
}


@end
