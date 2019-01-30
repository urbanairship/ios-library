/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAUser+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "UAKeychainUtils+Internal.h"
#import "UAPush+Internal.h"
#import "UAirship+Internal.h"
#import "UAConfig+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAUserTest : UABaseTest
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAConfig *config;

@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockUserClient;
@property (nonatomic, strong) id mockKeychainUtils;
@property (nonatomic, strong) id mockApplication;
@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];

    self.config = [[UAConfig alloc] init];
    self.config.inProduction = NO;
    self.config.developmentAppKey = @"9Q1tVTl0RF16baYKYp8HPQ";

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"user.test."];
    [self.dataStore removeAll];

    [[[NSBundle mainBundle] infoDictionary] setValue:@"someBundleID" forKey:@"CFBundleIdentifier"];
    self.mockKeychainUtils = [self mockForClass:[UAKeychainUtils class]];

    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockUserClient = [self mockForClass:[UAUserAPIClient class]];

    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.user = [UAUser userWithPush:self.mockPush config:self.config dataStore:self.dataStore client:self.mockUserClient notificationCenter:self.notificationCenter];
 }

- (void)tearDown {
    [self.dataStore removeAll];
    [super tearDown];
}

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values
    XCTAssertNotNil(self.user, @"we should at least have a user");
    XCTAssertNil(self.user.username, @"user name should be nil");
    XCTAssertNil(self.user.password, @"password should be nil");
    XCTAssertNil(self.user.url, @"url should be nil");
    XCTAssertFalse(self.user.isCreated, @"Uninitialized user should not be created");
}

/**
 * Test createUser when the request is successful
 */
-(void)testCreateUserSuccessful {
    __block UAUserAPIClientCreateSuccessBlock successBlock;

    UAUserData *userData = [UAUserData dataWithUsername:@"userName" password:@"password" url:@"http://url.com"];


    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];

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
    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];

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
    failureBlock(400);
    XCTAssertFalse(self.user.creatingUser, @"Should be finished creating user after the success block is called.");
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created.");
}

/**
 * Test updateUser
 */
-(void)testUpdateUser {
    //setup
    [self setupForUpdateUserTest];
    
    //test
    [self.user updateUser];
    
    //verify
    [self verifyUpdateUserTest];
}

-(void)setupForUpdateUserTest {
    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];


    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    [[self.mockUserClient expect] updateUser:self.user
                                   channelID:@"some-channel"
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
}

-(void)verifyUpdateUserTest {
    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be updated.");
}

/**
 * Test updateUser when no channel ID is present
 */
-(void)testUpdateUserNoChannelID {
    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    [self.user updateUser];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should not update if the channel ID is missing.");
}

/**
 * Test observing channel created notifications.
 */
-(void)testObserveChannelCreated {
    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];

    // Set up a default user
    self.user.username = @"username";
    self.user.password = @"password";

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *channelCreated = [self expectationWithDescription:@"Channel created"];

    // Expect an update call
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        [channelCreated fulfill];
    }] updateUser:OCMOCK_ANY channelID:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // Trigger the channel created notification
    [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                           object:nil
                                         userInfo:nil];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    XCTAssertNoThrow([self.mockUserClient verify]);
}

- (void)testEnablingDisabledUserUpdatesOrCreatesUser {
    // setup
    self.user.componentEnabled = NO;
    [self setupForUpdateUserTest];

    // test
    self.user.componentEnabled = YES;
    
    //verify
    [self verifyUpdateUserTest];
}


@end

