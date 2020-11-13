/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
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

static NSString * const UAUserUpdateTaskID = @"UAUser.update";
static NSString * const UAUserResetTaskID = @"UAUser.reset";

@interface UAUserTest : UAAirshipBaseTest
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockUserClient;
@property (nonatomic, strong) id mockTaskManager;
@property (nonatomic, strong) UAUserData *userData;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, copy) NSString *channelID;
@property (nonatomic, copy) UAChannelRegistrationExtenderBlock extenderBlock;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
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
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAUserUpdateTaskID,UAUserResetTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];


    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.userDataDAO = [[UATestUserDataDAO alloc] init];

    self.user = [UAUser userWithChannel:self.mockChannel
                              dataStore:self.dataStore
                                 client:self.mockUserClient
                     notificationCenter:self.notificationCenter
                            userDataDAO:self.userDataDAO
                            taskManager:self.mockTaskManager];

    self.userData = [UAUserData dataWithUsername:@"userName" password:@"password"];
 }

- (void)testDefaultUser {
    XCTestExpectation *expectation = [self expectationWithDescription:@"got user data"];

    [self.user getUserData:^(UAUserData *data) {
        XCTAssertNotNil(self.user, @"we should at least have a user");
        XCTAssertNil(data.username, @"user name should be nil");
        XCTAssertNil(data.password, @"password should be nil");
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateOnChannelCreation {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    [self.notificationCenter postNotificationName:UAChannelCreatedEvent object:nil];
    [self.mockTaskManager verify];
}

- (void)testUpdateOnInit {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    self.user = [UAUser userWithChannel:self.mockChannel
                              dataStore:self.dataStore
                                 client:self.mockUserClient
                     notificationCenter:self.notificationCenter
                            userDataDAO:self.userDataDAO
                            taskManager:self.mockTaskManager];
    [self.mockTaskManager verify];
}

- (void)testUpdateOnEnablement {
    self.user.enabled = NO;

    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    self.user.enabled = YES;
    [self.mockTaskManager verify];
}

- (void)testResetOnDeviceIDChange {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserResetTaskID options:OCMOCK_ANY];
    [self.notificationCenter postNotificationName:UADeviceIDChangedNotification object:nil];
    [self.mockTaskManager verify];
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

- (void)testResetTask {
    [self.userDataDAO saveUserData:self.userData completionHandler:^(BOOL success) {}];
    XCTAssertNotNil([self.userDataDAO getUserDataSync]);

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserResetTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);

    [mockTask verify];
}

- (void)testUpdateTaskCreatesChannel {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(UAUserData * _Nullable data, NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge  void (^)(UAUserData * _Nullable data, NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];

    completionHandler(self.userData, nil);
    XCTAssertEqualObjects(self.userDataDAO.getUserDataSync, self.userData, @"Saved and response user data should match");

    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUserCreateFailedRecoverableError {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(UAUserData * _Nullable data, NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge  void (^)(UAUserData * _Nullable data, NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];

    NSError *error = [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                         code:UAUserAPIClientErrorRecoverable
                                     userInfo:@{NSLocalizedDescriptionKey:@"neat"}];

    completionHandler(nil, error);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUserCreateFailedUnrecoverableError {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(UAUserData * _Nullable data, NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge  void (^)(UAUserData * _Nullable data, NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];

    NSError *error = [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                         code:UAUserAPIClientErrorUnrecoverable
                                     userInfo:@{NSLocalizedDescriptionKey:@"neat"}];

    completionHandler(nil, error);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskUpdatesUser {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-other-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        completionHandler = (__bridge  void (^)(NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];

    completionHandler(nil);
    [self.mockUserClient verify];
    [mockTask verify];
}


- (void)testUpdateTaskUpdatesUserRecoverableError {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    self.channelID = @"some-other-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        completionHandler = (__bridge  void (^)(NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];

    NSError *error = [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                         code:UAUserAPIClientErrorRecoverable
                                     userInfo:@{NSLocalizedDescriptionKey:@"neat"}];

    completionHandler(error);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskUpdatesUserUnrecoverableError {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    self.channelID = @"some-other-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    __block void (^completionHandler)(NSError * _Nullable error);
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        completionHandler = (__bridge  void (^)(NSError * _Nullable error))arg;
        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];

    NSError *error = [NSError errorWithDomain:UAUserAPIClientErrorDomain
                                         code:UAUserAPIClientErrorRecoverable
                                     userInfo:@{NSLocalizedDescriptionKey:@"neat"}];

    completionHandler(error);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskNoChannelID {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = nil;
    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskDisabled {
    self.user.enabled = NO;
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";
    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskAlreadyUpToDate {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
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

