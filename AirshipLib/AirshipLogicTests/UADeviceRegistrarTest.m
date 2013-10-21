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
#import "UADeviceRegistrar.h"
#import "UAChannelRegistrationPayload.h"
#import "UAHTTPRequest+Internal.h"

@interface UADeviceRegistrarTest : XCTestCase
@end

@implementation UADeviceRegistrarTest

id mockedDeviceClient;
id mockedChannelClient;
id mockedRegistrationDelegate;
id mockedRegistrarDelegate;

void (^channelUpdateSuccessDoBlock)(NSInvocation *);
void (^channelCreateSuccessDoBlock)(NSInvocation *);
void (^channelUpdateFailureDoBlock)(NSInvocation *);
void (^channelCreateFailureDoBlock)(NSInvocation *);


void (^deviceRegisterSuccessDoBlock)(NSInvocation *);
void (^deviceRegisterFailureDoBlock)(NSInvocation *);
void (^deviceUnregisterSuccessDoBlock)(NSInvocation *);
void (^deviceUnregisterFailureDoBlock)(NSInvocation *);

UAHTTPRequest *deviceFailureRequest;
UAHTTPRequest *channelFailureRequest;
NSString *channelCreateSuccessChannelID = @"newChannelID";



UAChannelRegistrationPayload *payload;
UADeviceRegistrar *registrar;


- (void)setUp {
    [super setUp];
    mockedDeviceClient = [OCMockObject niceMockForClass:[UADeviceAPIClient class]];
    mockedChannelClient = [OCMockObject niceMockForClass:[UAChannelAPIClient class]];

    mockedRegistrationDelegate = [OCMockObject niceMockForProtocol:@protocol(UARegistrationDelegate)];
    mockedRegistrarDelegate = [OCMockObject mockForProtocol:@protocol(UADeviceRegistrarDelegate)];

    registrar = [[UADeviceRegistrar alloc] init];
    registrar.deviceAPIClient = mockedDeviceClient;
    registrar.channelAPIClient = mockedChannelClient;
    registrar.registrarDelegate = mockedRegistrarDelegate;
    registrar.registrationDelegate = mockedRegistrationDelegate;

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
        successBlock(channelCreateSuccessChannelID);
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

    deviceRegisterFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock)arg;
        failureBlock(deviceFailureRequest);
    };

    deviceUnregisterSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock)arg;
        successBlock();
    };

    deviceUnregisterFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock)arg;
        failureBlock(deviceFailureRequest);
    };
}


- (void)tearDown {
    [super tearDown];
    
    [mockedDeviceClient stopMocking];
    [mockedChannelClient stopMocking];
    [mockedRegistrationDelegate stopMocking];
    [mockedRegistrarDelegate stopMocking];
}

/**
 * Test registerWithChannelID with valid channel ID and the request succeeds.
 */
- (void)testRegisterWithChannelID {

    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannel" deviceToken:payload.pushAddress];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on success with the channel ID and device token.");
}


/**
 * Test registerWithChannelID with valid channel ID and the request fails.
 */
- (void)testRegisterWithChannelIDFails {
    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationFailed];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on failure");
}

/**
 * Test registerWithChannelID with the same payload as the pending payload.
 */
- (void)testRegisterWithChannelIDSameAsPendingPayload {

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    // Add a pending request
    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    //Force it
    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about pending requests.");


    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is the same as the pending payload should skip registration");
}

/**
 * Test registerWithChannelID with the same payload as the previous successful
 * payload.
 */
- (void)testRegisterWithChannelIDSameAsPreviousSuccessPayload {
    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];
    // Add a succesfull request
    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
}

/**
 * Test registerWithChannelID where a new channel ID is created successfully.
 */
- (void)testRegisterNoChannelID {
    //Expect the channel client to create a channel and call success block
    [[[mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [[mockedRegistrarDelegate expect] channelIDCreated:channelCreateSuccessChannelID];
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:channelCreateSuccessChannelID
                                                               deviceToken:payload.pushAddress];


    [registrar registerWithChannelID:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device should clear any pending requests");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Registrar delegate should be notified of the created channel id");
}

/**
 * Test registerPushdDisabledWithChannelID with valid channel ID when the 
 * request succeeds.
 */
- (void)testRegisterPushDisabledWithChannelID {
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannel" deviceToken:payload.pushAddress];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on success with the channel and device tokens");
}

/**
 * Test registerPushdDisabledWithChannelID with valid channel ID when the 
 * request fails
 */
- (void)testRegisterPushDisabledWithChannelIDFails {
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationFailed];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on failure");
}

/**
 * Test registerPushdDisabledWithChannelID with the same payload as the pending
 * payload.
 */
- (void)testRegisterPushDisabledWithChannelIDSameAsPendingPayload {
    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is the same as the pending payload should skip registration");
}

/**
 * Test registerPushdDisabledWithChannelID with the same payload as the
 * previous successful payload.
 */
- (void)testRegisterPushDisabledWithChannelIDSameAsPreviousSuccessPayload {
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannel:@"someChannel"
                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [registrar registerPushDisabledWithChannelID:@"someChannel" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
}

/**
 * Test registerPushdDisabledWithChannelID without a channel id
 * tries to create a channel
 */
- (void)testRegisterPushDisabledNoChannelID {
    //Expect the channel client to create a channel and call success block
    [[[mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[mockedRegistrarDelegate expect] channelIDCreated:@"newChannelID"];
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"newChannelID"
                                                               deviceToken:payload.pushAddress];


    [registrar registerPushDisabledWithChannelID:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([mockedRegistrarDelegate verify], @"Registrar delegate should be notified of the created channel id");
}

/**
 * Test register  where a new channel ID failed to be created and
 * fallback to registering a device token.
 */
- (void)testRegisterWithPushDisableNoChannelIDFallback {
    payload.pushAddress = @"some-device-token";
    registrar.deviceTokenRegistered  = YES;

    // Set up failure with 501 so we fallback
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:501 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to create a channel and fail with 501
    [[[mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[[mockedDeviceClient expect] andDo:deviceUnregisterSuccessDoBlock] unregisterDeviceToken:payload.pushAddress
                                                                                    onSuccess:OCMOCK_ANY
                                                                                    onFailure:OCMOCK_ANY];

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:nil
                                                               deviceToken:payload.pushAddress];

    [registrar registerPushDisabledWithChannelID:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to unregister the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");

    // Reject any more unregister calls
    [[mockedDeviceClient reject] unregisterDeviceToken:OCMOCK_ANY
                                             onSuccess:OCMOCK_ANY
                                             onFailure:OCMOCK_ANY];

    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil withPayload:payload forcefully:NO], @"Registrar should not unregister the device token twice");


    payload.pushAddress = nil;
    registrar.deviceTokenRegistered  = YES;
    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil withPayload:payload forcefully:NO], @"Registrar should not try to unregister a nil device token");
}

/**
 * Test that registering with a nil channel id first tries to create a channel 
 * and falls back to registering the device token.
 */
- (void)testRegisterNoChannelFallback {
    payload.pushAddress = @"some-device-token";
    registrar.deviceTokenRegistered  = NO;

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

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:nil
                                                               deviceToken:payload.pushAddress];

    [registrar registerWithChannelID:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to register the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");

    // Reject any more unregister calls
    [[mockedDeviceClient reject] registerDeviceToken:OCMOCK_ANY
                                         withPayload:OCMOCK_ANY
                                           onSuccess:OCMOCK_ANY
                                           onFailure:OCMOCK_ANY];

    XCTAssertNoThrow( [registrar registerWithChannelID:nil withPayload:payload forcefully:NO], @"Registrar should not register the device token twice");


    payload.pushAddress = nil;
    registrar.deviceTokenRegistered  = NO;
    XCTAssertNoThrow([registrar registerWithChannelID:nil withPayload:payload forcefully:NO], @"Registrar should not try to register a nil device token");
}

@end
