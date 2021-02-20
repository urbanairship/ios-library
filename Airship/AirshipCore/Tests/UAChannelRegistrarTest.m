/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAPush.h"
#import "UARuntimeConfig.h"
#import "UANamedUser+Internal.h"
#import "UAirship.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestDate.h"
#import "UATestDispatcher.h"

static NSString * const UAChannelRegistrationTaskID = @"UAChannelRegistrar.registration";
static NSString * const UAChannelRegistrationActionKey = @"action";
static NSString * const UAChannelRegistrationCreateAction = @"create";
static NSString * const UAChannelRegistrationUpdateAction = @"update";

@interface UAChannelRegistrarTest : UAAirshipBaseTest

@property (nonatomic, strong) id mockedChannelClient;
@property (nonatomic, strong) id mockedRegistrarDelegate;
@property (nonatomic, strong) id mockTaskManager;

@property (nonatomic, strong) NSError *error;

@property (nonatomic, strong) UAChannelRegistrationPayload *payload;

@property (nonatomic, strong) UAChannelRegistrar *registrar;
@property (nonatomic, strong) UATestDate *testDate;

@property(nonatomic, copy) void (^launchHandler)(id<UATask>);

@end

@implementation UAChannelRegistrarTest

void (^channelUpdateSuccessDoBlock)(NSInvocation *);
void (^channelCreateSuccessDoBlock)(NSInvocation *, BOOL);
void (^channelUpdateFailureDoBlock)(NSInvocation *);
void (^channelCreateFailureDoBlock)(NSInvocation *, BOOL);

void (^deviceRegisterSuccessDoBlock)(NSInvocation *);

NSString * const MockChannelID = @"mockChannelID";
NSString * const ChannelCreateSuccessChannelID = @"newChannelID";

- (void)setUp {
    [super setUp];

    self.mockedChannelClient = [self mockForClass:[UAChannelAPIClient class]];
    self.mockedRegistrarDelegate = [self mockForProtocol:@protocol(UAChannelRegistrarDelegate)];
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
    self.testDate = [[UATestDate alloc] init];

    self.payload = [[UAChannelRegistrationPayload alloc] init];
    self.payload.pushAddress = @"someDeviceToken";
    __block UAChannelRegistrationPayload *copyOfPayload;

    [[[self.mockedRegistrarDelegate stub] andDo:^(NSInvocation *invocation) {
        // verify that createChannelPayload is called on the main thread.
        XCTAssertEqualObjects([NSThread currentThread],[NSThread mainThread]);

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAChannelRegistrationPayload *)  = (__bridge void (^)(UAChannelRegistrationPayload *)) arg;

        copyOfPayload = [self.payload copy];
        completionHandler(copyOfPayload);
    }] createChannelPayload:OCMOCK_ANY];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAChannelRegistrationTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.error = [NSError errorWithDomain:UAChannelAPIClientErrorDomain code:UAChannelAPIClientErrorUnsuccessfulStatus userInfo:@{}];

    channelUpdateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientUpdateCompletionHandler completionHandler = (__bridge UAChannelAPIClientUpdateCompletionHandler)arg;
        completionHandler(nil);
    };

    channelUpdateFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAChannelAPIClientUpdateCompletionHandler completionHandler = (__bridge UAChannelAPIClientUpdateCompletionHandler)arg;
        completionHandler(self.error);
    };

    channelCreateSuccessDoBlock = ^(NSInvocation *invocation, BOOL existing) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAChannelAPIClientCreateCompletionHandler completionHandler = (__bridge UAChannelAPIClientCreateCompletionHandler)arg;
        completionHandler(ChannelCreateSuccessChannelID, existing, nil);
    };

    channelCreateFailureDoBlock = ^(NSInvocation *invocation, BOOL existing) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAChannelAPIClientCreateCompletionHandler completionHandler = (__bridge UAChannelAPIClientCreateCompletionHandler)arg;
        completionHandler(nil, NO, self.error);
    };

    // Create the registrar
    self.registrar = [self createRegistrarWithChannelID:nil];

    [self.dataStore removeObjectForKey:UAChannelRegistrarChannelIDKey];
}

/**
 * Test successful registration
 */
- (void)testSuccessfulRegistration {
    // Setup by registering
    [self registerWithExisting:NO];

    // Verify
    [self verifyRegistrationSucceededDelegateCallback];

    [self verifyChannelClientCreateChannelWithPayload];
}

/**
 * Test for the CRA issue where if registration is already up to date, it would block future registrations
 * even if the CRA payload was out of date. CUSTENG-1212.
 */
- (void)testRegistrationBlockedIssue {
    // Expect the CRA to update for first registration
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:NO];
    [self expectRegistrationSucceededDelegateCallback];
    [self expectChannelCreatedDelegateCallbackWithExisting:NO];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];

    // Register - should skip due to everything being up to date.
    [self.registrar registerForcefully:NO];

    // Register forcefully again to verify registration is not blocked
    [self expectChannelClientUpdateChannelWithID:ChannelCreateSuccessChannelID andDo:channelUpdateSuccessDoBlock];
    [self expectRegistrationSucceededDelegateCallback];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:YES];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self forecefulRequestOptions]];

    // Register forcefully
    [self.registrar registerForcefully:YES];

    //Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientUpdateChannelWithID];
    [self.mockTaskManager verify];
}


/**
 * Test failed registration
 */
- (void)testFailedRegistration {
    // Expect the channel client to be asked to update the channel. Simulate failure.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateFailureDoBlock withExisting:NO];

    // Other expectations
    [self expectRegistrationFailedDelegateCallback];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationFailedDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];
    [self.mockTaskManager verify];
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
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];

    // Time travel forward to simulate 24 hours have passed
    self.testDate.timeOffset = (24 * 60 * 60);

    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientUpdateChannelWithID:ChannelCreateSuccessChannelID andDo:channelUpdateSuccessDoBlock];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientUpdateChannelWithID];

    // Try again with correct lastSuccessfulUpdateDate - should skip registration
    // Reject any update channel calls
    [self rejectChannelClientUpdateChannel];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self verifyRejectChannelClientUpdateChannel];
    [self.mockTaskManager verify];
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
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];

    // Expect the channel client to update the channel and call the updateChannel block when we call run it forcefully
    [self expectChannelClientUpdateChannelWithID:ChannelCreateSuccessChannelID andDo:channelUpdateSuccessDoBlock];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:YES];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self forecefulRequestOptions]];

    // Register forcefully
    [self.registrar registerForcefully:YES];

    //Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientUpdateChannelWithID];

    // Reject a update call on another non-forceful update with the same payload
    [self rejectChannelClientUpdateChannel];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register one more time non-forcefully
    [self.registrar registerForcefully:NO];

    // Verify
    [self verifyRejectChannelClientUpdateChannel];
    [self.mockTaskManager verify];
}

/**
 * Test that a channel update with a conflict error tries to
 * create a new channel ID.
 */
- (void)testChannelConflictNewChannel {
    BOOL existing = YES;

    // Assume we recently registered
    self.registrar = [self createRegistrarWithChannelID:MockChannelID];

    // Expect the channel client to try to update channel. Simulate failure.
    self.error = [NSError errorWithDomain:UAChannelAPIClientErrorDomain code:UAChannelAPIClientErrorConflict userInfo:@{}];
    [self expectChannelClientUpdateChannelWithID:MockChannelID andDo:channelUpdateFailureDoBlock];

    // Expect create channel to be called. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyChannelClientUpdateChannelWithID];
    [self verifyChannelClientCreateChannelWithPayload];
    [self verifyRegistrationSucceededDelegateCallback];
    [self.mockTaskManager verify];
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
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];
    [self.mockTaskManager verify];
}

- (void)testExistingFlagYES {
    BOOL existing = YES;

    // Expect the channel client to be asked to update the channel. Simulate success.
    [self expectChannelClientCreateChannelWithPayloadAndDo:channelCreateSuccessDoBlock withExisting:existing];

    // Other expectations
    [self expectRegistrationSucceededDelegateCallback];
    [self expectChannelCreatedDelegateCallbackWithExisting:existing];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:[self requestOptions]];

    // Register
    [self.registrar registerForcefully:NO];

    // Verify
    [self waitForTestExpectations];
    [self verifyRegistrationSucceededDelegateCallback];
    [self verifyChannelClientCreateChannelWithPayload];
    [self.mockTaskManager verify];
}

/**
 * Test channel ID is returned when channel ID exists.
 */
- (void)testChannelID {
    [self.dataStore setValue:MockChannelID forKey:UAChannelRegistrarChannelIDKey];
    
    XCTAssertEqualObjects(self.registrar.channelID, MockChannelID, @"Should return channel ID");
}

/**
 * Test channelID returns nil when channel ID does not exist.
 */
- (void)testChannelIDNoChannel {
    [self.dataStore removeObjectForKey:UAChannelRegistrarChannelIDKey];
    
    XCTAssertNil(self.registrar.channelID, @"Channel ID should be nil");
}

#pragma mark -
#pragma mark Utility methods

- (UATaskRequestOptions *)requestOptions {
    return [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyKeep
                                           requiresNetwork:YES
                                                    extras:@{@"forcefully" : @(NO)}];
}

- (UATaskRequestOptions *)forecefulRequestOptions {
    return [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace
                                           requiresNetwork:YES
                                                    extras:@{@"forcefully" : @(YES)}];
}

- (id<UATask>)registrationTask:(BOOL)forceful {
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    UATaskRequestOptions *options = forceful ? [self forecefulRequestOptions] : [self requestOptions];

    [[[mockTask stub] andReturn:UAChannelRegistrationTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    return mockTask;
}

- (void)launchRegistrationTask:(BOOL)forceful {
    self.launchHandler([self registrationTask:forceful]);
}
/**
 * Create a new registrar. Usually called by setup(), but also used in some tests when channelID needs to be set
 */
- (UAChannelRegistrar *)createRegistrarWithChannelID:(NSString *)channelID {
    UAChannelRegistrar *registrar = [UAChannelRegistrar channelRegistrarWithConfig:self.config
                                                                         dataStore:self.dataStore
                                                                         channelID:channelID
                                                                  channelAPIClient:self.mockedChannelClient
                                                                              date:self.testDate
                                                                        dispatcher:[UATestDispatcher testDispatcher]
                                                                       taskManager:self.mockTaskManager];
    registrar.delegate = self.mockedRegistrarDelegate;
    
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

    UATaskRequestOptions *options = existing ? [self forecefulRequestOptions] : [self requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [self launchRegistrationTask:NO];
    }] enqueueRequestWithID:UAChannelRegistrationTaskID options:options];

    // Register
    [self.registrar registerForcefully:existing];

    // Verify
    [self waitForTestExpectations];
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
    id channelCreatedExpectation = [self expectationWithDescription:@"channelCreated:existing:"];
    [[[self.mockedRegistrarDelegate stub] andDo:^(NSInvocation *invocation) {
        [channelCreatedExpectation fulfill];
    }] channelCreated:OCMOCK_ANY existing:existing];
}

- (void)rejectChannelCreatedDelegateCallback {
    [[self.mockedRegistrarDelegate reject] channelCreated:OCMOCK_ANY existing:YES];
    [[self.mockedRegistrarDelegate reject] channelCreated:OCMOCK_ANY existing:NO];
}

- (void)expectChannelClientCreateChannelWithPayloadAndDo:(void (^)(NSInvocation *, BOOL))doBlock withExisting:(BOOL)existing {
    XCTestExpectation *expectation = [self expectationWithDescription:@"[UAChannelAPIClient's createChannelWithPayload should be called"];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
        doBlock(invocation, existing);
    }] createChannelWithPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
              completionHandler:OCMOCK_ANY];
}

- (void)verifyChannelClientCreateChannelWithPayload {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"UAChannelAPIClient's createChannelWithPayload should be called.");
}

- (void)expectChannelClientUpdateChannelWithID:(NSString *)channelID andDo:(void (^)(NSInvocation *))doBlock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"UAChannelAPIClient's updateChannelWithID should be called"];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
        doBlock(invocation);
    }] updateChannelWithID:channelID
               withPayload:[OCMArg checkWithSelector:@selector(isEqualToPayload:) onObject:self.payload]
         completionHandler:OCMOCK_ANY];
}

- (void)verifyChannelClientUpdateChannelWithID {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Expected updateChannel call.");
}
- (void)rejectChannelClientUpdateChannel {
    [[self.mockedChannelClient reject] updateChannelWithID:OCMOCK_ANY
                                               withPayload:OCMOCK_ANY
                                         completionHandler:OCMOCK_ANY];
}

- (void)verifyRejectChannelClientUpdateChannel {
    XCTAssertNoThrow([self.mockedChannelClient verify], @"Unexpected updateChannel call.");
}

@end
