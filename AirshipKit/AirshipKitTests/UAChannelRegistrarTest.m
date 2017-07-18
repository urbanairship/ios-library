/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAChannelAPIClient+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAPush.h"
#import "UAConfig.h"
#import "UANamedUser+Internal.h"
#import "UAirship.h"
#import "XCTestExpectation+AsyncFulfill.h"

@interface UAChannelRegistrarTest : XCTestCase

@property (nonatomic, strong) id mockedChannelClient;
@property (nonatomic, strong) id mockedRegistrarDelegate;
@property (nonatomic, strong) id mockedUAPush;
@property (nonatomic, strong) id mockedUAirship;
@property (nonatomic, strong) id mockedUAConfig;

@property (nonatomic, assign) NSUInteger failureCode;
@property (nonatomic, copy) NSString *channelCreateSuccessChannelID;
@property (nonatomic, copy) NSString *channelCreateSuccessChannelLocation;

@property (nonatomic, strong) UAChannelRegistrationPayload *payload;
@property (nonatomic, strong) UAChannelRegistrar *registrar;
@property bool clearNamedUser;
@property bool existing;

@property (nonatomic, strong) XCTestExpectation *channelUpdateSuccessExpectation;
@property (nonatomic, strong) XCTestExpectation *channelUpdateFailureExpectation;
@property (nonatomic, strong) XCTestExpectation *channelCreateSuccesstestExpectation;
@property (nonatomic, strong) XCTestExpectation *channelCreateFailureExpectation;

@end

@implementation UAChannelRegistrarTest

void (^channelUpdateSuccessDoBlock)(NSInvocation *);
void (^channelCreateSuccessDoBlock)(NSInvocation *);
void (^channelUpdateFailureDoBlock)(NSInvocation *);
void (^channelCreateFailureDoBlock)(NSInvocation *);

void (^deviceRegisterSuccessDoBlock)(NSInvocation *);

- (void)setUp {
    [super setUp];

    self.existing = YES;
    self.clearNamedUser = YES;

    self.channelCreateSuccessChannelID = @"newChannelID";
    self.channelCreateSuccessChannelLocation = @"newChannelLocation";

    self.mockedChannelClient = [OCMockObject niceMockForClass:[UAChannelAPIClient class]];

    self.mockedRegistrarDelegate = [OCMockObject niceMockForProtocol:@protocol(UAChannelRegistrarDelegate)];

    self.mockedUAPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockedUAConfig = [OCMockObject niceMockForClass:[UAConfig class]];
    [[[self.mockedUAConfig stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_clearNamedUser];
    }] clearNamedUserOnAppRestore];

    self.mockedUAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedUAirship stub] andReturn:self.mockedUAirship] shared];
    [[[self.mockedUAirship stub] andReturn:self.mockedUAConfig] config];
    [[[self.mockedUAirship stub] andReturn:self.mockedUAPush] push];


    self.registrar = [[UAChannelRegistrar alloc] init];
    self.registrar.channelAPIClient = self.mockedChannelClient;
    self.registrar.delegate = self.mockedRegistrarDelegate;

    self.payload = [[UAChannelRegistrationPayload alloc] init];
    self.payload.pushAddress = @"someDeviceToken";

    self.failureCode = 400;

    channelUpdateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientUpdateSuccessBlock successBlock = (__bridge UAChannelAPIClientUpdateSuccessBlock)arg;
        successBlock();

        [self.channelUpdateSuccessExpectation fulfillAfter:0.05];
    };

    channelUpdateFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAChannelAPIClientFailureBlock failureBlock = (__bridge UAChannelAPIClientFailureBlock)arg;
        failureBlock(self.failureCode);
        
        [self.channelUpdateFailureExpectation fulfillAfter:0.05];
    };

    channelCreateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAChannelAPIClientCreateSuccessBlock successBlock = (__bridge UAChannelAPIClientCreateSuccessBlock)arg;
        successBlock(self.channelCreateSuccessChannelID, self.channelCreateSuccessChannelLocation, self.existing);
        
        [self.channelCreateSuccesstestExpectation fulfillAfter:0.05];
    };

    channelCreateFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientFailureBlock failureBlock = (__bridge UAChannelAPIClientFailureBlock)arg;
        failureBlock(self.failureCode);
        
        [self.channelCreateFailureExpectation fulfillAfter:0.2];
    };
}

- (void)expectChannelCreateFailure
{
    self.channelCreateFailureExpectation = [self expectationWithDescription:@"channelCreateFailureExpectation"];
}

- (void)expectChannelCreateSuccess
{
    self.channelCreateSuccesstestExpectation = [self expectationWithDescription:@"channelCreateSuccesstestExpectation"];
}

- (void)expectChannelUpdateFailure
{
    self.channelUpdateFailureExpectation = [self expectationWithDescription:@"channelUpdateFailureExpectation"];
}

- (void)expectChannelUpdateSuccess
{
    self.channelUpdateSuccessExpectation = [self expectationWithDescription:@"channelUpdateSuccessExpectation"];
}

- (void)tearDown {
    [self.mockedChannelClient stopMocking];
    [self.mockedRegistrarDelegate stopMocking];
    [self.mockedUAConfig stopMocking];
    [self.mockedUAPush stopMocking];
    [self.mockedUAirship stopMocking];

    [super tearDown];
}

/**
 * Test successful register with a channel
 */
- (void)testRegisterWithChannel {

    // Expect the channel client to update channel and call the update block
    [[[self.mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                        withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                          onSuccess:OCMOCK_ANY
                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];

    [self expectChannelUpdateSuccess];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel ID.");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called.");
    }];

}

/**
 * Test failed register with a channnel
 */
- (void)testRegisterWithChannelFail {
    // Expect the channel client to update channel and call the update block
    [[[self.mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];

    [self expectChannelUpdateFailure];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Registering should always cancel all requests and call updateChannel with passed payload and channel ID.");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on failure");
    }];
}

/**
 * Test register with a channel ID with the same payload as the last successful
 * registration payload.
 */
- (void)testRegisterWithChannelDuplicate {
    // Expect the channel client to update channel and call the update block
    [[[self.mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    [self expectChannelUpdateSuccess];

    // Add a successful request
    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"");
    }];

    // Expect it again when we call run it forcefully
    [[[self.mockedChannelClient expect] andDo:channelUpdateSuccessDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];


    [self expectChannelUpdateSuccess];

    // Run it again forcefully
    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:YES];

    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Registering forcefully should not care about previous requests.");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called");
    }];

    // Run it normally, it should not call update
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                withPayload:OCMOCK_ANY
                                                  onSuccess:OCMOCK_ANY
                                                  onFailure:OCMOCK_ANY];

    // Delegate should still be called
    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:self.payload];

    
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"allow async handling"];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];
    [testExpectation fulfillAfter:0.05];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Registering with a payload that is already registered should skip");
    }];
}

/**
 * Test register without a channel creates a channel
 */
- (void)testRegisterNoChannel {
    // Expect the channel client to create a channel and call success block
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:self.channelCreateSuccessChannelID channelLocation:self.channelCreateSuccessChannelLocation existing:YES];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
    }];
}

/**
 * Test register without a channel location fails to creates a channel
 */
- (void)testRegisterNoChannelLocation {
    // Expect the channel client to fail to create a channel and call failure block
    [[[self.mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                          onSuccess:OCMOCK_ANY
                                                                                          onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];

    [self expectChannelCreateFailure];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:nil withPayload:self.payload forcefully:NO];
    
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on failure");
    }];
}

/**
 * Test that registering when a request is in progress
 * does not attempt to register again
 */
- (void)testRegisterRequestInProgress {
    // Expect the channel client to create a channel and not call either block so the
    // request stays pending
    [[self.mockedChannelClient expect] createChannelWithPayload:OCMOCK_ANY
                                                 onSuccess:OCMOCK_ANY
                                                 onFailure:OCMOCK_ANY];


    XCTestExpectation *testExpectation = [self expectationWithDescription:@"channelCreateFailureExpectation"];

    // Make a pending request
    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    // Reject any registration requests
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[self.mockedChannelClient reject] createChannelWithPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [testExpectation fulfillAfter:0.05];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO], @"A pending request should ignore any further requests.");
        XCTAssertNoThrow([self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:YES], @"A pending request should ignore any further requests.");
    }];
}

/**
 * Test cancelAllRequests
 */
- (void)testCancelAllRequests {
    self.registrar.lastSuccessPayload = [[UAChannelRegistrationPayload alloc] init];
    self.registrar.isRegistrationInProgress = NO;
    [[self.mockedChannelClient expect] cancelAllRequests];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"channelCreateFailureExpectation"];
    [self.registrar cancelAllRequests];

    [testExpectation fulfillAfter:0.05];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should cancel all of its requests.");
        XCTAssertNotNil(self.registrar.lastSuccessPayload, @"Last success payload should not be cleared if a request is not in progress.");
    }];

    self.registrar.isRegistrationInProgress = YES;
    [[self.mockedChannelClient expect] cancelAllRequests];

    XCTestExpectation *testExpectation2 = [self expectationWithDescription:@"channelCreateFailureExpectation"];
    [self.registrar cancelAllRequests];

    [testExpectation2 fulfillAfter:0.05];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNil(self.registrar.lastSuccessPayload, @"Last success payload should be cleared if a request is in progress.");
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should cancel all of its requests.");
    }];
}

/**
 * Test that a channel update with a 409 status tries to 
 * create a new channel ID.
 */
- (void)testChannelConflictNewChannel {
    self.failureCode = 409;

    //Expect the channel client to update channel and call the update block
    [[[self.mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the create channel to be called, make it successful
    self.channelCreateSuccessChannelID = @"newChannel";
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];


    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:@"newChannel" channelLocation:self.channelCreateSuccessChannelLocation existing:YES];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];
    
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Conflict with the channel ID should create a new channel");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Registration delegate should be called with the new channel");
    }];
}

/**
 * Test that a channel update with a 409 fails to create a new
 * channel.
 */
- (void)testChannelConflictFailed {
    self.failureCode = 409;

    //Expect the channel client to update channel and call the update block
    [[[self.mockedChannelClient expect] andDo:channelUpdateFailureDoBlock] updateChannelWithLocation:@"someLocation"
                                                                                    withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                      onSuccess:OCMOCK_ANY
                                                                                      onFailure:OCMOCK_ANY];

    // Expect the create channel to be called, make it fail
    [[[self.mockedChannelClient expect] andDo:channelCreateFailureDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    // Expect the delegate to be called
    [[self.mockedRegistrarDelegate expect] registrationFailedWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];

    [self expectChannelCreateFailure];

    [self.registrar registerWithChannelID:@"someChannel" channelLocation:@"someLocation" withPayload:self.payload forcefully:NO];
    
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Conflict with the channel ID should try to create a new channel");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on failure");
    }];
}

/**
 * Test disassociate when channel existed and flag is YES.
 */
- (void)testDisassociateChannelExistFlagYes {
    // set to an existing channel
    self.existing = YES;

    // set clearNamedUserOnAppRestore
    self.clearNamedUser = YES;

    // Expect the channel client to create a channel and call success block
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                          onSuccess:OCMOCK_ANY
                                                                                          onFailure:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:self.channelCreateSuccessChannelID channelLocation:self.channelCreateSuccessChannelLocation existing:YES];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
    }];
}

/**
 * Test disassociate not called when channel is new and flag is YES
 */
- (void)testNewChannelFlagYes {
    // set to new channel
    self.existing = NO;

    // set clearNamedUserOnAppRestore
    self.clearNamedUser = YES;

    // Expect the channel client to create a channel and call success block
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                          onSuccess:OCMOCK_ANY
                                                                                          onFailure:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:self.channelCreateSuccessChannelID channelLocation:self.channelCreateSuccessChannelLocation existing:NO];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
    }];
}

/**
 * Test disassociate not called when channel existed and flag is NO
 */
- (void)testChannelExistFlagNo {
    // set to an existing channel
    self.existing = YES;

    // set clearNamedUserOnAppRestore
    self.clearNamedUser = NO;

    // Expect the channel client to create a channel and call success block
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                          onSuccess:OCMOCK_ANY
                                                                                          onFailure:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:self.channelCreateSuccessChannelID channelLocation:self.channelCreateSuccessChannelLocation existing:YES];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
    }];
}

/**
 * Test disassociate not called when channel is new and flag is NO
 */
- (void)testNewChannelFlagNo {
    // set to new channel
    self.existing = NO;

    // set clearNamedUserOnAppRestore
    self.clearNamedUser = NO;

    // Expect the channel client to create a channel and call success block
    [[[self.mockedChannelClient expect] andDo:channelCreateSuccessDoBlock] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                                                                                          onSuccess:OCMOCK_ANY
                                                                                          onFailure:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceededWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]];
    [[self.mockedRegistrarDelegate expect] channelCreated:self.channelCreateSuccessChannelID channelLocation:self.channelCreateSuccessChannelLocation existing:NO];

    [self expectChannelCreateSuccess];

    [self.registrar registerWithChannelID:nil channelLocation:nil withPayload:self.payload forcefully:NO];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should create a new create request");
        XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate should be called on success");
    }];
}

@end
