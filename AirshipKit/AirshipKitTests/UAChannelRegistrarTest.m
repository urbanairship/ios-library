/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAPush.h"
#import "UAConfig.h"
#import "UANamedUser+Internal.h"
#import "UAirship.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestDate.h"
#import "UATestDispatcher.h"

@interface UAChannelRegistrarTest : UABaseTest

@property (nonatomic, strong) id mockedChannelClient;
@property (nonatomic, strong) id mockedRegistrarDelegate;
@property (nonatomic, strong) id mockedApplication;

@property (nonatomic, assign) NSUInteger failureCode;

@property (nonatomic, strong) UAChannelRegistrationPayload *payload;

@property (nonatomic, strong) UAChannelRegistrar *registrar;
@property (nonatomic, strong) UATestDate *testDate;

@end

@implementation UAChannelRegistrarTest

void (^channelUpdateSuccessDoBlock)(NSInvocation *);
void (^channelCreateSuccessDoBlock)(NSInvocation *, BOOL);
void (^channelUpdateFailureDoBlock)(NSInvocation *);
void (^channelCreateFailureDoBlock)(NSInvocation *, BOOL);

void (^deviceRegisterSuccessDoBlock)(NSInvocation *);

NSString * const MockChannelID = @"mockChannelID";
NSString * const MockChannelLocation = @"mockChannelLocation";
NSString * const ChannelCreateSuccessChannelID = @"newChannelID";
NSString * const ChannelCreateSuccessChannelLocation = @"newChannelLocation";

- (void)setUp {
    [super setUp];

    self.mockedChannelClient = [self mockForClass:[UAChannelAPIClient class]];

    self.mockedRegistrarDelegate = [self mockForProtocol:@protocol(UAChannelRegistrarDelegate)];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockedApplication stub] andReturn:self.mockedApplication] sharedApplication];

    self.payload = [[UAChannelRegistrationPayload alloc] init];
    self.payload.pushAddress = @"someDeviceToken";
    __block UAChannelRegistrationPayload *copyOfPayload;
    [[[self.mockedRegistrarDelegate stub] andDo:^(NSInvocation *invocation) {
        // verify that createChannelPayload is called on the main thread.
        XCTAssertEqualObjects([NSThread currentThread],[NSThread mainThread]);

        copyOfPayload = [self.payload copy];
        [invocation setReturnValue:&copyOfPayload];
    }] createChannelPayload];

    self.failureCode = 400;

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
        failureBlock(self.failureCode);
    };

    channelCreateSuccessDoBlock = ^(NSInvocation *invocation, BOOL existing) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAChannelAPIClientCreateSuccessBlock successBlock = (__bridge UAChannelAPIClientCreateSuccessBlock)arg;
        successBlock(ChannelCreateSuccessChannelID, ChannelCreateSuccessChannelLocation, existing);
    };

    channelCreateFailureDoBlock = ^(NSInvocation *invocation, BOOL existing) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientFailureBlock failureBlock = (__bridge UAChannelAPIClientFailureBlock)arg;
        failureBlock(self.failureCode);
    };

    self.testDate = [[UATestDate alloc] init];

    // Create the registrar
    self.registrar = [self createRegistrarWithChannelID:nil location:nil];
}

/**
 * Test successful registration
 */
- (void)testSuccessfulRegistration {
    // Setup by registering
    [self registerWithExisting:NO];

    // Verify
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];
}

/**
 * Test failed registration
 */
- (void)testFailedRegistration {
    // Expect the channel client to be asked to update the channel. Simulate failure.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateFailureDoBlock withExisting:NO];

    // Other expectations
    [self expectRegistrationFailedDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationFailedDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];
}

/**
 * Test register with a channel ID with the same payload as the last successful
 * registration payload results in update if 24 hours has passed since last update
 * and is rejected otherwise.
 */
- (void)testRegisterWithChannelDuplicateAfter24Hours {
    BOOL existing = NO;

    // Expect the channel client to be asked to create the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];

    // Time travel forward to simulate 24 hours have passed
    self.testDate.timeOffset = (24 * 60 * 60);

    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientUpdateChannelWithLocation:ChannelCreateSuccessChannelLocation andDo:channelUpdateSuccessDoBlock];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientUpdateChannelWithLocation];

    // Try again with correct lastSuccessfulUpdateDate - should skip registration
    // Reject any update channel calls
    [self rejectChannelClientUpdateChannel];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self verifyRejectChannelClientUpdateChannel];
}

/**
 * Test register with a channel ID with the same payload as the last successful
 * registration payload.
 */
- (void)testRegisterWithChannelDuplicate {
    BOOL existing = NO;

    // Expect the channel client to be asked to create the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];

    // Expect the channel client to update the channel and call the updateChannel block when we call run it forcefully
    [self expectChannelClientUpdateChannelWithLocation:ChannelCreateSuccessChannelLocation andDo:channelUpdateSuccessDoBlock];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register forcefully
    [self.registrar registerForcefully:YES];

    //Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientUpdateChannelWithLocation];

    // Reject a update call on another non-forceful update with the same payload
    [self rejectChannelClientUpdateChannel];

    // Register one more time non-forcefully
    [self.registrar registerForcefully:NO];

    // Verify
    [self verifyRejectChannelClientUpdateChannel];
}


/**
 * Test that registering when a request is in progress
 * does not attempt to register again
 */
- (void)testRegisterRequestInProgress {
    BOOL existing = NO;
    __block UAChannelAPIClientCreateSuccessBlock successBlock;
    [self startRegistrationButLeaveInProgressWithExisting:existing successBlock:&successBlock];

    // Reject any registration requests
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[self.mockedChannelClient reject] createChannelWithPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // Register
    XCTAssertNoThrow([self.registrar registerForcefully:NO], @"A pending request should ignore any further requests.");
    XCTAssertNoThrow([self.registrar registerForcefully:YES], @"A pending request should ignore any further requests.");

    // Finish original registration
    successBlock(ChannelCreateSuccessChannelID, ChannelCreateSuccessChannelLocation, existing);

    // Wait until original registration completes
    [self expectBackgroundTaskToBeStopped];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyBackgroundTaskWasStopped];
}

- (void)testUpdateRegistrationExistingBackgroundTask {
    // Setup by starting, but not completing, registration
    BOOL existing = NO;
    __block UAChannelAPIClientCreateSuccessBlock successBlock;
    [self startRegistrationButLeaveInProgressWithExisting:existing successBlock:&successBlock];

    [[self.mockedApplication reject] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.registrar registerForcefully:NO];

    XCTAssertNoThrow([self.mockedApplication verify], @"A background task should not be requested if one already exists");
}

/**
 * Tests create channel registration when background task is invalid.
 */
- (void)testChannelCreationBackgroundInvalid {
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Reject any registration requests
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[self.mockedChannelClient reject] createChannelWithPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // Make a pending request
    [self.registrar registerForcefully:NO];

    XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should get no requests");
}

/**
 * Tests update registration when background task is invalid.
 */
- (void)testUpdateRegistrationInvalidBackgroundTask {
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Reject any registration requests
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY withPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];
    [[self.mockedChannelClient reject] createChannelWithPayload:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // Simulate active channel
    self.registrar = [self createRegistrarWithChannelID:MockChannelID location:MockChannelLocation];

    // Make a pending request
    [self.registrar registerForcefully:NO];

    XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should get no requests");
}

/**
 * Test cancelAllRequests
 */
- (void)testCancelAllRequestsRegistrationNotInProgress {
    // Setup by registering
    [self registerWithExisting:NO];

    // Expectations
    [[self.mockedChannelClient expect] cancelAllRequests];

    // Test
    [self.registrar cancelAllRequests];

    // Verify
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should cancel all of its requests.");
    XCTAssertNotNil(self.registrar.lastSuccessfulPayload, @"Last success payload should not be cleared if a request is not in progress.");
    XCTAssertNotEqualObjects(self.registrar.lastSuccessfulUpdateDate,[NSDate distantPast],@"Last success date should not be cleared if a request is not in progress.");
}

- (void)testCancelAllRequestsRegistrationInProgress {
    // Setup by starting, but not completing, registration
    BOOL existing = NO;
    __block UAChannelAPIClientCreateSuccessBlock successBlock;
    [self startRegistrationButLeaveInProgressWithExisting:existing successBlock:&successBlock];

    // Expectations
    [[self.mockedChannelClient expect] cancelAllRequests];

    // Test
    [self.registrar cancelAllRequests];

    // Verify
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Channel client should cancel all of its requests.");
    XCTAssertNil(self.registrar.lastSuccessfulPayload, @"Last success payload should be cleared if a request is in progress.");
    XCTAssertEqualObjects(self.registrar.lastSuccessfulUpdateDate,[NSDate distantPast],@"Last success date should be cleared if a request is in progress.");
}

/**
 * Test that a channel update with a 409 status tries to
 * create a new channel ID.
 */
- (void)testChannelConflictNewChannel {
    BOOL existing = YES;

    // Assume we recently registered
    self.registrar = [self createRegistrarWithChannelID:MockChannelID location:MockChannelLocation];

    // Expect the channel client to try to update channel. Simulate failure.
    self.failureCode = 409;
    [self expectChannelClientUpdateChannelWithLocation:MockChannelLocation andDo:channelUpdateFailureDoBlock];

    // Expect create channel to be called. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyChannelClientUpdateChannelWithLocation];
    [self verifyChannelClientCreateChannelWithPayload];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
}

/**
 * Test that a channel update with a 409 and the following channel create with a 409 fails to create a new channel.
 */
- (void)testChannelConflictFailed {
    // Assume we recently registered
    self.registrar = [self createRegistrarWithChannelID:MockChannelID location:MockChannelLocation];

    // Expect the channel client to try to update channel. Simulate failure.
    self.failureCode = 409;
    [self expectChannelClientUpdateChannelWithLocation:MockChannelLocation andDo:channelUpdateFailureDoBlock];

    // Expect create channel to be called. Simulate failure.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateFailureDoBlock withExisting:NO];

    // Expect the delegate to be called
    [self expectRegistrationFailedDelegateCallback];
    [self rejectChannelCreatedDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyChannelClientUpdateChannelWithLocation];
    [self verifyChannelClientCreateChannelWithPayload];
    [self verifyRegistrationFailedDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
}

/**
 * Test existing flag passes through to delegate
 */
- (void)testExistingFlagNO {
    BOOL existing = NO;

    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];
}

- (void)testExistingFlagYES {
    BOOL existing = YES;

    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyBackgroundTaskWasStartedAndStopped];
    [self verifyChannelClientCreateChannelWithPayload];
}

/**
 * Test channel ID is returned when both channel ID and channel location exist.
 */
- (void)testChannelID {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];
    
    XCTAssertEqualObjects(self.registrar.channelID, @"channel ID", @"Should return channel ID");
}

/**
 * Test channelID returns nil when channel ID does not exist.
 */
- (void)testChannelIDNoChannel {
    [self.dataStore removeObjectForKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];
    
    XCTAssertNil(self.registrar.channelID, @"Channel ID should be nil");
}

/**
 * Test channelID returns nil when channel location does not exist.
 */
- (void)testChannelIDNoLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore removeObjectForKey:@"UAChannelLocation"];
    
    XCTAssertNil(self.registrar.channelID, @"Channel ID should be nil");
}

/**
 * Test channel location is returned when both channel ID and channel location exist.
 */
- (void)testChannelLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];
    
    XCTAssertEqualObjects(self.registrar.channelLocation, @"channel Location", @"Should return channel location");
}

/**
 * Test channelLocation returns nil when channel ID does not exist.
 */
- (void)testChannelLocationNoChannel {
    [self.dataStore removeObjectForKey:@"UAChannelID"];
    [self.dataStore setValue:@"channel Location" forKey:@"UAChannelLocation"];
    
    XCTAssertNil(self.registrar.channelLocation, @"Channel location should be nil");
}

/**
 * Test channelLocation returns nil when channel location does not exist.
 */
- (void)testChannelLocationNoLocation {
    [self.dataStore setValue:@"channel ID" forKey:@"UAChannelID"];
    [self.dataStore removeObjectForKey:@"UAChannelLocation"];
    
    XCTAssertNil(self.registrar.channelLocation, @"Channel location should be nil");
}




#pragma mark -
#pragma mark Utility methods

/**
 * Create a new registrar. Usually called by setup(), but also used in some tests when channelID & channelLocation need to be set
 */
- (UAChannelRegistrar *)createRegistrarWithChannelID:(NSString *)channelID location:(NSString *)channelLocation {
    UAChannelRegistrar *registrar = [UAChannelRegistrar channelRegistrarWithConfig:[UAConfig config]
                                                                         dataStore:self.dataStore
                                                                          delegate:self.mockedRegistrarDelegate
                                                                         channelID:channelID
                                                                   channelLocation:channelLocation
                                                                  channelAPIClient:self.mockedChannelClient
                                                                              date:self.testDate
                                                                        dispatcher:[UATestDispatcher testDispatcher]];
    return registrar;
}

/**
 * Register
 */
- (void)registerWithExisting:(BOOL)existing {
    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectBackgroundTaskToBeStartedAndStopped];

    // Register
    [self.registrar registerForcefully:existing];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

/**
 * Start registration but leave it in progress
 */
- (void)startRegistrationButLeaveInProgressWithExisting:(BOOL)existing successBlock:(UAChannelAPIClientCreateSuccessBlock *)successBlock {
    *successBlock = ^(NSString *channelID, NSString *channelLocation, BOOL existing) {
        XCTFail(@"This block should be overwritten during the test");
    };
    void (^channelCreateSuccessDoDelayedBlock)(NSInvocation *, BOOL) = ^(NSInvocation *invocation, BOOL existing) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        *successBlock = (__bridge UAChannelAPIClientCreateSuccessBlock)arg;
    };

    // Expect the channel client to be asked to create the channel. Don't call back, to keep the request pending.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoDelayedBlock withExisting:existing];

    [self expectBackgroundTaskToBeStarted];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForExpectationsWithTimeout:1 handler:nil];
    [self verifyChannelClientCreateChannelWithPayload];
    [self verifyBackgroundTaskWasStarted];
    [self verifyChannelClientCreateChannelWithPayload];
}

- (void)expectRegistrationSucceededDelegateCallback {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Delegate's registrationSucceeded method should be called"];

    [[[self.mockedRegistrarDelegate expect] andDo:^(NSInvocation *invocation) {
        UA_LDEBUG(@"registrationSucceeded called");
        [expectation fulfill];
    }] registrationSucceeded];
}

- (void)verifyRegistrationSucceededDelegateCallback {
    XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate's registrationSucceeded method should be called on success");
}

- (void)expectRegistrationFailedDelegateCallback {
    XCTestExpectation *expectation = [self expectationWithDescription:@"registrationFailed"];

    [[[self.mockedRegistrarDelegate expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] registrationFailed];
}

- (void)verifyRegistrationFailedDelegateCallback {
    XCTAssertNoThrow([self.mockedRegistrarDelegate verify], @"Delegate's registrationFailed method should be called on failure");
}

- (void)expectChannelCreatedDelegateCallbackWithExisting:(BOOL)existing {
    id channelCreatedExpectation = [self expectationWithDescription:@"channelCreated:location:existing:"];
    [[[self.mockedRegistrarDelegate stub] andDo:^(NSInvocation *invocation) {
        [channelCreatedExpectation fulfill];
    }] channelCreated:OCMOCK_ANY channelLocation:OCMOCK_ANY existing:existing];
}

- (void)rejectChannelCreatedDelegateCallback {
    [[self.mockedRegistrarDelegate reject] channelCreated:OCMOCK_ANY channelLocation:OCMOCK_ANY existing:YES];
    [[self.mockedRegistrarDelegate reject] channelCreated:OCMOCK_ANY channelLocation:OCMOCK_ANY existing:NO];
}

- (void)expectBackgroundTaskToBeStartedAndStopped {
    [self expectBackgroundTaskToBeStarted];
    [self expectBackgroundTaskToBeStopped];
}

- (void)verifyBackgroundTaskWasStartedAndStopped {
    XCTAssertNoThrow([self.mockedApplication verify], @"begin and end background task should be called.");
}

NSUInteger backgroundTaskID = 30;
- (void)expectBackgroundTaskToBeStarted {
    XCTestExpectation *beginExpectation = [self expectationWithDescription:@"Begin Background Task expected to be called"];
    [[[self.mockedApplication expect] andDo:^(NSInvocation *invocation) {
        [beginExpectation fulfill];
        [invocation setReturnValue:(void *)&backgroundTaskID];
    }] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
}

- (void)verifyBackgroundTaskWasStarted {
    XCTAssertNoThrow([self.mockedApplication verify], @"begin background task should be called.");
}

- (void)expectBackgroundTaskToBeStopped {
    XCTestExpectation *endExpectation = [self expectationWithDescription:@"End Background Task expected to be called"];
    [[[self.mockedApplication expect] andDo:^(NSInvocation *invocation) {
        [endExpectation fulfill];
    }] endBackgroundTask:backgroundTaskID];
}

- (void)verifyBackgroundTaskWasStopped {
    XCTAssertNoThrow([self.mockedApplication verify], @"end background task should be called.");
}

- (void)expectChannelClientCreateChannelWithPayloadAndDo:(void (^)(NSInvocation *, BOOL))doBlock withExisting:(BOOL)existing {
    XCTestExpectation *expectation = [self expectationWithDescription:@"[UAChannelAPIClient's createChannelWithPayload should be called"];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
        doBlock(invocation, existing);
    }] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                      onSuccess:OCMOCK_ANY
                      onFailure:OCMOCK_ANY];
}

- (void)verifyChannelClientCreateChannelWithPayload {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"UAChannelAPIClient's createChannelWithPayload should be called.");
}

- (void)expectChannelClientUpdateChannelWithLocation:(NSString *)channelLocation andDo:(void (^)(NSInvocation *))doBlock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"UAChannelAPIClient's updateChannelWithLocation should be called"];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
        doBlock(invocation);
    }] updateChannelWithLocation:channelLocation
                     withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
                       onSuccess:OCMOCK_ANY
                       onFailure:OCMOCK_ANY];
}

- (void)verifyChannelClientUpdateChannelWithLocation {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Expected updateChannel call.");
}
- (void)rejectChannelClientUpdateChannel {
    [[self.mockedChannelClient reject] updateChannelWithLocation:OCMOCK_ANY
                                                     withPayload:OCMOCK_ANY
                                                       onSuccess:OCMOCK_ANY
                                                       onFailure:OCMOCK_ANY];
}

- (void)verifyRejectChannelClientUpdateChannel {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Unexpected updateChannel call.");
}

@end
