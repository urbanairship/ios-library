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
@end

@implementation UADeviceRegistrarTest

id mockedDeviceClient;
id mockedChannelClient;
id mockedRegistrationDelegate;
id mockedNSNotificationCenter;

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
NSString *channelCreateSuccessChannelID;
NSString *channelCreateSuccessChannelLocation;


UAChannelRegistrationPayload *payload;
UADeviceRegistrar *registrar;


- (void)setUp {
    [super setUp];

    channelCreateSuccessChannelID = @"newChannelID";
    channelCreateSuccessChannelLocation = @"newChannelLocation";

    mockedDeviceClient = [OCMockObject niceMockForClass:[UADeviceAPIClient class]];
    mockedChannelClient = [OCMockObject niceMockForClass:[UAChannelAPIClient class]];

    mockedRegistrationDelegate = [OCMockObject niceMockForProtocol:@protocol(UARegistrationDelegate)];

    registrar = [[UADeviceRegistrar alloc] init];
    registrar.deviceAPIClient = mockedDeviceClient;
    registrar.channelAPIClient = mockedChannelClient;
    registrar.registrationDelegate = mockedRegistrationDelegate;

    payload = [[UAChannelRegistrationPayload alloc] init];
    payload.pushAddress = @"someDeviceToken";

    channelFailureRequest = [[UAHTTPRequest alloc] init];
    deviceFailureRequest = [[UAHTTPRequest alloc] init];

    mockedNSNotificationCenter = [OCMockObject niceMockForClass:[NSNotificationCenter class]];
    [[[mockedNSNotificationCenter stub] andReturn:mockedNSNotificationCenter] defaultCenter];

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
    [mockedNSNotificationCenter stopMocking];
}

/**
 * Test registerWithChannelID with valid channel ID and the request succeeds.
 */
- (void)testRegisterWithChannelID {

    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannel" deviceToken:payload.pushAddress];
    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be called on success with the channel ID and device token.");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}


/**
 * Test registerWithChannelID with valid channel ID and the request fails.
 */
- (void)testRegisterWithChannelIDFails {
    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationFailed];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on failure");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");

}

/**
 * Test registerWithChannelID with the same payload as the pending payload.
 */
- (void)testRegisterWithChannelIDSameAsPendingPayload {

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    // Add a pending request
    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];
    

    //Force it
    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about pending requests.");

    

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Reject if the channel client tries to update the channel
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];


    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is the same as the pending payload should skip registration");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}

/**
 * Test registerWithChannelID with the same payload as the previous successful
 * payload.
 */
- (void)testRegisterWithChannelIDSameAsPreviousSuccessPayload {
    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Add a succesfull request
    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];


    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}

/**
 * Test registerWithChannelID with the same payload as the previous successful
 * payload but different then the current pending.
 */
- (void)testRegisterWithChannelIDSameAsPreviousSuccessPayloadDifferentPending {
    //Expect the channel client to update channel and call the update block
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannel:@"someChannel"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];
    // Add a succesfull request
    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    UAChannelRegistrationPayload *previousPayload = [payload copy];

    // modify payload for pending
    payload.alias =  @"some-alias";
    [registrar registerWithChannelID:@"someChannel" withPayload:payload forcefully:NO];

    // Expect a different pending payload calls through
    [[mockedChannelClient expect] updateChannel:OCMOCK_ANY
                                    withPayload:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];


    // Register again with the previous payload
    [registrar registerWithChannelID:@"someChannel" withPayload:previousPayload forcefully:NO];

    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered, but is different then the current pending should call through.");
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

    NSDictionary *expectedUserInfo = @{UAChannelNotificationKey : channelCreateSuccessChannelID,
                                       UAChannelLocationNotificationKey: channelCreateSuccessChannelLocation};

    [[mockedNSNotificationCenter expect] postNotificationName:UAChannelCreatedNotification
                                                       object:nil
                                                     userInfo:[OCMArg checkWithSelector:@selector(isEqualToDictionary:) onObject:expectedUserInfo]];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:channelCreateSuccessChannelID
                                                               deviceToken:payload.pushAddress];

    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device should clear any pending requests");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted for finished registration and creating a channel id.");
}

/**
 * Test registerPushdDisabledWithChannelID with valid channel ID when the 
 * request succeeds.
 */
- (void)testRegisterPushDisabledWithChannelID {
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"someChannel" deviceToken:payload.pushAddress];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on success with the channel and device tokens");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}

/**
 * Test registerPushdDisabledWithChannelID with valid channel ID when the 
 * request fails
 */
- (void)testRegisterPushDisabledWithChannelIDFails {
    [[[mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[mockedRegistrationDelegate expect] registrationFailed];

    [[mockedDeviceClient expect] cancelAllRequests];
    [[mockedChannelClient expect] cancelAllRequests];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedDeviceClient verify], @"Registering should always cancel current and pending requests.");
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel id.");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Delegate should be called on failure");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}

/**
 * Test registerPushdDisabledWithChannelID with the same payload as the pending
 * payload.
 */
- (void)testRegisterPushDisabledWithChannelIDSameAsPendingPayload {
    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];


    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];


    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is the same as the pending payload should skip registration");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
}

/**
 * Test registerPushdDisabledWithChannelID with the same payload as the
 * previous successful payload.
 */
- (void)testRegisterPushDisabledWithChannelIDSameAsPreviousSuccessPayload {
    [[[mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];

    [[mockedChannelClient expect] updateChannelWithLocation:@"someLocation"
                                                withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:payload]
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];


    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:YES];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering forefully should not care about previous requests.");

    // Reject any
    [[mockedDeviceClient reject] cancelAllRequests];
    [[mockedChannelClient reject] cancelAllRequests];

    //Expect the channel client to update channel and call the update block
    [[mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
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


    NSDictionary *expectedUserInfo = @{UAChannelNotificationKey : channelCreateSuccessChannelID,
                                       UAChannelLocationNotificationKey: channelCreateSuccessChannelLocation};

    [[mockedNSNotificationCenter expect] postNotificationName:UAChannelCreatedNotification
                                                       object:nil
                                                     userInfo:[OCMArg checkWithSelector:@selector(isEqualToDictionary:) onObject:expectedUserInfo]];

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"newChannelID"
                                                               deviceToken:payload.pushAddress];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should create a new create request");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted for finished registration and creating a channel id.");
}

/**
 * Test register  where a new channel ID failed to be created and
 * fallback to registering a device token.
 */
- (void)testRegisterWithPushDisableNoChannelIDFallback {
    payload.pushAddress = @"some-device-token";
    registrar.isDeviceTokenRegistered  = YES;

    // Set up failure with 501 so we fallback
    channelFailureRequest.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:501 HTTPVersion:nil headerFields:nil];

    //Expect the channel client to create a channel and fail with 501
    [[[mockedChannelClient stub] andDo:channelCreateFailureDoBlock] createChannelWithPayload:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    [[[mockedDeviceClient expect] andDo:deviceUnregisterSuccessDoBlock] unregisterDeviceToken:payload.pushAddress
                                                                                    onSuccess:OCMOCK_ANY
                                                                                    onFailure:OCMOCK_ANY];

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:nil
                                                               deviceToken:payload.pushAddress];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to unregister the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");

    // Reject any more unregister calls
    [[mockedDeviceClient reject] unregisterDeviceToken:OCMOCK_ANY
                                             onSuccess:OCMOCK_ANY
                                             onFailure:OCMOCK_ANY];
    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not unregister the device token twice");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");


    payload.pushAddress = nil;
    registrar.isDeviceTokenRegistered  = YES;
    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    XCTAssertNoThrow([registrar registerPushDisabledWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO], @"Registrar should not try to unregister a nil device token");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted on registration finish.");
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

    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:nil
                                                               deviceToken:payload.pushAddress];

    [registrar registerWithChannelID:nil channelLocation:nil withPayload:payload forcefully:NO];

    XCTAssertNoThrow([mockedDeviceClient verify], @"Device client should be called to register the device token");
    XCTAssertNoThrow([mockedChannelClient verify], @"Channel client should attempt to create a channel id");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the successful registration");

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
 * Test that a channel update with a 409 status tries to 
 * create a new channel id and sends a ChannelConflict notification.
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
    [[mockedRegistrationDelegate expect] registrationSucceededForChannelID:@"newChannel" deviceToken:OCMOCK_ANY];


    // Expected notification user info
    NSDictionary *userInfo =  @{UAChannelNotificationKey: @"newChannel",
                                UAChannelLocationNotificationKey:@"newChannelLocation",
                                UAReplacedChannelNotificationKey:@"someChannel",
                                UAReplacedChannelLocationNotificationKey:@"someLocation"};


    [[mockedNSNotificationCenter expect] postNotificationName:UAChannelConflictNotification
                                                       object:nil
                                                     userInfo:[OCMArg checkWithSelector:@selector(isEqualToDictionary:) onObject:userInfo]];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Conflict with the channel id should create a new channel");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be called with the new channel");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"A notification should be posted about the conflict and registration finishing.");
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
    [[mockedRegistrationDelegate expect] registrationFailed];


    // Reject a conflict notification
    [[mockedNSNotificationCenter reject] postNotificationName:UAChannelConflictNotification
                                                       object:nil
                                                     userInfo:OCMOCK_ANY];

    [[mockedNSNotificationCenter expect] postNotificationName:UADeviceRegistrationFinishedNotification object:nil];

    [registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:payload forcefully:NO];
    XCTAssertNoThrow([mockedChannelClient verify], @"Conflict with the channel id should try to create a new channel");
    XCTAssertNoThrow([mockedRegistrationDelegate verify], @"Registration delegate should be notified of the registration failure.");
    XCTAssertNoThrow([mockedNSNotificationCenter verify], @"Only a notification should be posted about the device registration finishing.");
}

@end
