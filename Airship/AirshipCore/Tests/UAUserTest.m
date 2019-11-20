/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAUser+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "UAKeychainUtils.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestDispatcher.h"
#import "UARuntimeConfig+Internal.h"
#import "UAChannel+Internal.h"
#import "UAAppStateTracker.h"

@interface UATestUserDataDAO : UAUserDataDAO
@property (nonatomic, strong) UAUserData *userData;
@end

@interface UAUserTest : UABaseTest
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDispatcher *testDispatcher;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockUserClient;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) UAUserData *userData;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, strong) NSString *channelID;
@property (nonatomic, copy) UAChannelRegistrationExtenderBlock extenderBlock;
@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        NSString *channelID = self.channelID;
        [invocation setReturnValue:(void *)&channelID];
    }] identifier];

    // Capture the channel payload extender
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
          void *arg;
          [invocation getArgument:&arg atIndex:2];
          self.extenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
    }] addChannelExtenderBlock:OCMOCK_ANY];

    self.mockUserClient = [self mockForClass:[UAUserAPIClient class]];
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.userDataDAO = [[UATestUserDataDAO alloc] init];
    self.testDispatcher = [UATestDispatcher testDispatcher];

    self.user = [UAUser userWithChannel:self.mockChannel
                              dataStore:self.dataStore
                                 client:self.mockUserClient
                     notificationCenter:self.notificationCenter
                            application:self.mockApplication
                   backgroundDispatcher:self.testDispatcher
                            userDataDAO:self.userDataDAO];

    self.userData = [UAUserData dataWithUsername:@"userName" password:@"password"];

    self.user.enabled = YES;
 }

- (void)testDefaultUser {
    //an uninitialized user will be non-nil but will have nil values

    XCTestExpectation *expectation = [self expectationWithDescription:@"got user data"];

    [self.user getUserData:^(UAUserData *data) {
        XCTAssertNotNil(self.user, @"we should at least have a user");
        XCTAssertNil(data.username, @"user name should be nil");
        XCTAssertNil(data.password, @"password should be nil");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];
}

/**
 * Test successful user creation on channel creation.
 */
-(void)testUserCreationOnChannelCreation {
    [self verifyUserCreationWithInitBlock:^{
        [self.notificationCenter postNotificationName:UAChannelCreatedEvent object:nil];
    }];
}

/**
 * Test successful user creation on foreground.
 */
-(void)testUserCreationOnForeground {
    [self verifyUserCreationWithInitBlock:^{
        [self.notificationCenter postNotificationName:UAApplicationWillEnterForegroundNotification
                                               object:nil];
    }];
}

/**
 * Test user updates on component enablement if the channel changes.
 */
-(void)testCreationOnComponentEnablement {
    self.user.enabled = NO;

    [self verifyUserCreationWithInitBlock:^{
        self.user.enabled = YES;
    }];
}

/**
 * Test user updates on active if the channel changes.
 */
-(void)testUserUpdateOnChannelChange {
    [self verifyUserUpdateWithInitBlock:^{
        [self.notificationCenter postNotificationName:UAChannelCreatedEvent object:nil];
    }];
}

/**
 * Test user updates on foreground if the channel changes.
 */
-(void)testUserUpdateOnActive {
    [self verifyUserUpdateWithInitBlock:^{
        [self.notificationCenter postNotificationName:UAApplicationWillEnterForegroundNotification
                                               object:nil];
    }];
}

/**
 * Test user updates on active if the channel changes.
 */
-(void)testUserUpdateOnComponentEnablement {
    [self verifyUserUpdateWithInitBlock:^{
        self.user.enabled = NO;
        self.user.enabled = YES;
    }];
}

/**
 * Test user ID is added to the CRA payload.
 */
- (void)testRegistrationPayload {
    [self.userDataDAO saveUserData:self.userData completionHandler:^(BOOL success) {}];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    self.extenderBlock(payload, ^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(self.userData.username, payload.userID);
        [extendedPayload fulfill];
    });

    [self waitForTestExpectations];
}

- (void)verifyUserUpdateWithInitBlock:(void (^)(void))initBlock {
    // Create the user first
    [self verifyUserCreationWithInitBlock:^{
        [self.notificationCenter postNotificationName:UAChannelCreatedEvent object:nil];
    }];

    self.channelID = @"some-other-channel";

    XCTestExpectation *userUpdated = [self expectationWithDescription:@"user updated"];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAUserAPIClientUpdateSuccessBlock successBlock = (__bridge UAUserAPIClientUpdateSuccessBlock)arg;
        successBlock();
        [userUpdated fulfill];
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] updateUserWithData:self.userData
                                                              channelID:self.channelID
                                                              onSuccess:OCMOCK_ANY
                                                              onFailure:OCMOCK_ANY];


    // Expect the background task
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockApplication expect] endBackgroundTask:1];

    initBlock();

    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [self.mockApplication verify];
}

- (void)verifyUserCreationWithInitBlock:(void (^)(void))initBlock {
    self.channelID = @"some-channel";

    XCTestExpectation *userCreated = [self expectationWithDescription:@"user created"];

    void (^andDoBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAUserAPIClientCreateSuccessBlock successBlock = (__bridge UAUserAPIClientCreateSuccessBlock)arg;
        successBlock(self.userData);
        [userCreated fulfill];
    };

    [[[self.mockUserClient expect] andDo:andDoBlock] createUserWithChannelID:self.channelID
                                                                   onSuccess:OCMOCK_ANY
                                                                   onFailure:OCMOCK_ANY];

    // Expect the background task
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    [[self.mockApplication expect] endBackgroundTask:1];

    initBlock();

    [self waitForTestExpectations];
    XCTAssertEqualObjects(self.userDataDAO.getUserDataSync, self.userData, @"Saved and response user data should match");
    [self.mockUserClient verify];
    [self.mockApplication verify];
}

@end

@implementation UATestUserDataDAO
- (nullable UAUserData *)getUserDataSync {
    return self.userData;
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    [dispatcher dispatchAsync:^{
        completionHandler(self.userData);
    }];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler {
    completionHandler(self.userData);
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue {
    if (queue) {
        dispatch_async(queue, ^{
            completionHandler(self.userData);
        });
    } else {
        completionHandler(self.userData);
    }
}

- (void)saveUserData:(UAUserData *)data completionHandler:(void (^)(BOOL))completionHandler {
    self.userData = data;
    completionHandler(YES);
}

- (void)clearUser {
    self.userData = nil;
}

@end

