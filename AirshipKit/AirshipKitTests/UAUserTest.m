/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAUser+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUserData.h"
#import "UAKeychainUtils+Internal.h"
#import "UAPush+Internal.h"
#import "UAirship+Internal.h"
#import "UAConfig+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAUserTest : UABaseTest
@property (nonatomic, strong) UAUser *user;
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

    [[[NSBundle mainBundle] infoDictionary] setValue:@"someBundleID" forKey:@"CFBundleIdentifier"];
    self.mockKeychainUtils = [self mockForClass:[UAKeychainUtils class]];

    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockUserClient = [self mockForClass:[UAUserAPIClient class]];
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.user = [UAUser userWithPush:self.mockPush
                              config:self.config
                           dataStore:self.dataStore
                              client:self.mockUserClient
                  notificationCenter:self.notificationCenter
                         application:self.mockApplication];
 }

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values

    XCTestExpectation *expectation = [self expectationWithDescription:@"got user data"];

    [self.user getUserData:^(UAUserData *data) {
        XCTAssertNotNil(self.user, @"we should at least have a user");
        XCTAssertNil(data.username, @"user name should be nil");
        XCTAssertNil(data.password, @"password should be nil");
        XCTAssertNil(data.url, @"url should be nil");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertNil(self.user.username, @"user name should be nil");
    XCTAssertNil(self.user.password, @"password should be nil");
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertNil(self.user.url, @"url should be nil");
    XCTAssertFalse(self.user.isCreated, @"Uninitialized user should not be created");
#pragma GCC diagnostic pop
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
        successBlock(userData, @{});
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
    XCTestExpectation *userCreated = [self expectationWithDescription:@"user created"];

    [self.user createUser:^(UAUserData *data) {
        [userCreated fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created");
    XCTAssertEqualObjects(self.user.userData, userData, @"Saved and response user data should match");
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
        failureBlock(400);
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:@"some-channel"
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *createFinished = [self expectationWithDescription:@"create finished"];

    [self.user createUser:^(UAUserData *data) {
        XCTAssertNil(data);
        [createFinished fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should call the client to be created.");
}

/**
 * Test updateUser
 */
-(void)testUpdateUser {

    XCTestExpectation *updateCalledExpectation = [self expectationWithDescription:@"update called"];

    //setup
    [self setupForUpdateUserTest:updateCalledExpectation];

    XCTestExpectation *updated = [self expectationWithDescription:@"user updated"];
    
    //test
    [self.user updateUser:^{
        [updated fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];
    
    //verify
    [self verifyUpdateUserTest];
}

-(void)setupForUpdateUserTest:(XCTestExpectation *)updateCalledExpectation {
    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];

    // Set up a default user
    self.user.userData = [UAUserData dataWithUsername:@"username" password:@"password" url:@"url"];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAUserAPIClientUpdateSuccessBlock successBlock = (__bridge UAUserAPIClientUpdateSuccessBlock)arg;
        successBlock();
        [updateCalledExpectation fulfill];
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] updateUser:self.user channelID:@"some-channel" onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

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
    self.user.userData = [UAUserData dataWithUsername:@"username" password:@"password" url:@"url"];

    [[self.mockUserClient reject] updateUser:OCMOCK_ANY
                                   channelID:OCMOCK_ANY
                                   onSuccess:OCMOCK_ANY
                                   onFailure:OCMOCK_ANY];

    XCTestExpectation *updated = [self expectationWithDescription:@"user updated"];

    [self.user updateUser:^{
        [updated fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertNoThrow([self.mockUserClient verify], @"User should not update if the channel ID is missing.");
}

/**
 * Test observing channel created notifications.
 */
-(void)testObserveChannelCreated {
    [[[self.mockPush stub] andReturn:@"some-channel"] channelID];

    // Set up a default user
    self.user.userData = [UAUserData dataWithUsername:@"username" password:@"password" url:@"url"];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *updated = [self expectationWithDescription:@"User udpated"];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAUserAPIClientUpdateSuccessBlock successBlock = (__bridge UAUserAPIClientUpdateSuccessBlock)arg;
        successBlock();
        [updated fulfill];
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] updateUser:self.user channelID:@"some-channel" onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // Trigger the channel created notification
    [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                           object:nil
                                         userInfo:nil];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockUserClient verify]);
}

- (void)testEnablingDisabledUserUpdatesOrCreatesUser {
    // setup
    self.user.componentEnabled = NO;

    XCTestExpectation *updateCalled = [self expectationWithDescription:@"update called"];

    [self setupForUpdateUserTest:updateCalled];

    // test
    self.user.componentEnabled = YES;

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    //verify
    [self verifyUpdateUserTest];
}

@end

